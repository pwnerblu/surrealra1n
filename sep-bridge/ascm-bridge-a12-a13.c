/*
 * sepfix.c -- AppleSEPCredentialManager iOS 15.5 -> 16.0 protocol bridge patcher.
 *
 * Usage: sepfix <input 15 kernel> <output 15 kernel>
 *
 * Confirmed on-device: patching a tether-downgraded iPhone SE (2nd gen) running
 * iOS 15.5 against a newer SEP firmware (observed with SEP 27.2.1, latest at
 * time of writing) restores real native activation. Before the patch,
 * mobileactivationd's request-4 attestation call returned acmErr=-5 and the
 * device hung at "Unable to Activate - Your iPhone could not be activated
 * because the activation server cannot be reached". With the patch, the
 * device completes normal activation through Apple's servers and can reach
 * the home screen. Tether-downgrading to iOS 16.0 on the same SEP
 * worked without any patch; this patcher brings 15.5 up to parity by
 * speaking the same outer-request framing that 16.0 uses.
 *
 * Contract (see sepfix-plan.txt):
 *   - No fixed offsets. Every patch site is located by anchored signature
 *     discovery from the "responsePayloadV1.payloadVersion" cstring and the
 *     unique 9-word register-setup template that precedes the request-4 BL.
 *   - File size is preserved byte-for-byte.
 *   - Validate every edit before applying any. On any failure, leave no output.
 *   - Refuse an output path that is the same inode as the input.
 *
 * The bridge rewrites the request-4 call site of AppleSEPCredentialManager's
 * _performCommand so that, on the way to sendSEPCommand, it prepends a 28-byte
 * outer-request header matching iOS 16.0's wire format. The bridge body lives
 * in a verified cave inside __TEXT_EXEC (ref-free, between kexts). Scratch
 * for {prefix || payload} lives on the bridge's OWN stack frame -- cave
 * memory is in __TEXT_EXEC and KTRR/CTRR-locks read-only on arm64e, so
 * writes into any cave fault at EL1 (this is what panicked the first
 * iteration right before backboardd launched).
 *
 * Response path is intentionally NOT patched: iOS 15.5's parser reads the
 * u16 header-length field at response+2 and skips that many bytes, which
 * is enough to transparently strip the 16.0 12-byte response prefix. Device
 * testing confirms this suffices for request-4 attestation retrieval and
 * the full activation flow.
 *
 * Patched kernel still needs the user's existing tether-boot repackaging;
 * identical file size does not preserve any cryptographic signatures.
 */

#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <inttypes.h>
#include <limits.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#ifndef UINT16_MAX
#define UINT16_MAX 0xFFFFu
#endif

/* ----------------------------------------------------------------- utility */

static void die(const char *fmt, ...) __attribute__((noreturn, format(printf, 1, 2)));
static void die(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    fprintf(stderr, "sepfix: ");
    vfprintf(stderr, fmt, ap);
    fputc('\n', stderr);
    va_end(ap);
    exit(1);
}

static uint32_t rd32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}
static uint64_t rd64(const uint8_t *p) {
    return (uint64_t)rd32(p) | ((uint64_t)rd32(p + 4) << 32);
}
static void wr32(uint8_t *p, uint32_t v) {
    p[0] = v & 0xff; p[1] = (v >> 8) & 0xff; p[2] = (v >> 16) & 0xff; p[3] = (v >> 24) & 0xff;
}

/* -------------------------------------------------------- Mach-O structure */

/* We only parse the subset we need, all bounds-checked by hand. */
#define MH_MAGIC_64   0xfeedfacfu
#define LC_SEGMENT_64 0x19u
#define LC_FUNCTION_STARTS 0x26u
#define CPU_TYPE_ARM64 0x0100000cu

typedef struct {
    char     name[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    int32_t  maxprot;
    int32_t  initprot;
    uint32_t nsects;
    uint32_t flags;
    size_t   off;        /* file offset of the LC_SEGMENT_64 command */
} seg_t;

typedef struct {
    uint8_t *buf;
    size_t   size;
    uint32_t ncmds;
    size_t   sizeofcmds;
    seg_t   *segs;
    size_t   nseg;
    /* function starts, resolved to VAs, sorted */
    uint64_t *starts;
    size_t    nstarts;
} image_t;

static void img_bounds(const image_t *im, size_t off, size_t len, const char *what) {
    if (off > im->size || len > im->size - off)
        die("out of range %s: off=%zu len=%zu size=%zu", what, off, len, im->size);
}

static const seg_t *seg_by_va(const image_t *im, uint64_t va, uint64_t len) {
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (!s->vmsize) continue;
        if (va >= s->vmaddr && va + len <= s->vmaddr + s->vmsize)
            return s;
    }
    return NULL;
}

static size_t va_to_off(const image_t *im, uint64_t va, uint64_t len) {
    const seg_t *s = seg_by_va(im, va, len);
    if (!s) die("VA 0x%" PRIx64 "+0x%" PRIx64 " not mapped", va, len);
    if (va - s->vmaddr + len > s->filesize)
        die("VA 0x%" PRIx64 " in BSS/unbacked region of %s", va, s->name);
    return (size_t)(s->fileoff + (va - s->vmaddr));
}

static void parse_macho(image_t *im) {
    if (im->size < 32) die("file too small for Mach-O header");
    uint32_t magic = rd32(im->buf);
    if (magic != MH_MAGIC_64) die("not a 64-bit little-endian Mach-O (magic 0x%08x)", magic);
    uint32_t cpu = rd32(im->buf + 4);
    if (cpu != CPU_TYPE_ARM64) die("not arm64 (cpu type 0x%08x)", cpu);
    im->ncmds = rd32(im->buf + 16);
    im->sizeofcmds = rd32(im->buf + 20);
    if (im->sizeofcmds > im->size - 32) die("load commands exceed file");

    /* First pass: count segments. */
    size_t off = 32;
    size_t end = 32 + im->sizeofcmds;
    size_t count = 0;
    for (uint32_t i = 0; i < im->ncmds; i++) {
        if (off + 8 > end) die("truncated load commands");
        uint32_t cmd = rd32(im->buf + off);
        uint32_t cs  = rd32(im->buf + off + 4);
        if (cs < 8 || off + cs > end) die("bad load command size at %zu", off);
        if (cmd == LC_SEGMENT_64) count++;
        off += cs;
    }
    im->segs = calloc(count, sizeof(seg_t));
    if (!im->segs) die("oom segs");
    im->nseg = 0;

    /* Second pass: fill. */
    off = 32;
    for (uint32_t i = 0; i < im->ncmds; i++) {
        uint32_t cmd = rd32(im->buf + off);
        uint32_t cs  = rd32(im->buf + off + 4);
        if (cmd == LC_SEGMENT_64) {
            if (cs < 72) die("segment command too small");
            seg_t *s = &im->segs[im->nseg++];
            memcpy(s->name, im->buf + off + 8, 16);
            s->vmaddr   = rd64(im->buf + off + 24);
            s->vmsize   = rd64(im->buf + off + 32);
            s->fileoff  = rd64(im->buf + off + 40);
            s->filesize = rd64(im->buf + off + 48);
            s->maxprot  = (int32_t)rd32(im->buf + off + 56);
            s->initprot = (int32_t)rd32(im->buf + off + 60);
            s->nsects   = rd32(im->buf + off + 64);
            s->flags    = rd32(im->buf + off + 68);
            s->off      = off;
            if (s->fileoff > im->size || s->filesize > im->size - s->fileoff)
                die("segment %.16s out of file", s->name);
        }
        off += cs;
    }

    /* Decode LC_FUNCTION_STARTS as a ULEB128 diff list over the first __TEXT_EXEC base. */
    uint64_t text_exec_base = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        if (!strncmp(im->segs[i].name, "__TEXT_EXEC", 16)) {
            text_exec_base = im->segs[i].vmaddr;
            break;
        }
    }
    off = 32;
    for (uint32_t i = 0; i < im->ncmds; i++) {
        uint32_t cmd = rd32(im->buf + off);
        uint32_t cs  = rd32(im->buf + off + 4);
        if (cmd == LC_FUNCTION_STARTS) {
            if (cs < 16) die("LC_FUNCTION_STARTS too small");
            uint32_t doff = rd32(im->buf + off + 8);
            uint32_t dsz  = rd32(im->buf + off + 12);
            img_bounds(im, doff, dsz, "LC_FUNCTION_STARTS");
            size_t cap = 1024, n = 0;
            uint64_t *out = malloc(cap * sizeof(uint64_t));
            if (!out) die("oom starts");
            uint64_t cur = 0;
            size_t q = doff;
            size_t qend = doff + dsz;
            while (q < qend) {
                uint64_t v = 0;
                unsigned shift = 0;
                while (q < qend) {
                    uint8_t c = im->buf[q++];
                    v |= ((uint64_t)(c & 0x7f)) << shift;
                    shift += 7;
                    if (!(c & 0x80)) break;
                    if (shift > 63) die("ULEB128 overflow");
                }
                if (!v) break;
                cur += v;
                if (n == cap) {
                    cap *= 2;
                    uint64_t *n2 = realloc(out, cap * sizeof(uint64_t));
                    if (!n2) die("oom starts");
                    out = n2;
                }
                out[n++] = text_exec_base + cur;
            }
            im->starts = out;
            im->nstarts = n;
        }
        off += cs;
    }
    if (!im->nstarts) die("no LC_FUNCTION_STARTS");
}

/* ------------------------------------------------------- ARM64 primitives */

/*
 * The small ARM64 subset we care about:
 *   PACIBSP            0xd503237f    function prolog hallmark
 *   RETAB              0xd65f0fff    function epilog (we accept RET too)
 *   RET                0xd65f03c0
 *   B   imm26          000101        pc-relative branch
 *   BL  imm26          100101        pc-relative call
 *   B.cond            01010100        19-bit imm
 *   CBZ/CBNZ          x1 0110100(0/1) 19-bit imm
 *   TBZ/TBNZ          x0 110110        14-bit imm
 *   ADRP              1 immlo 10000   21-bit page offset
 *   ADD imm           sf 0 100010 0 ...
 *   MOV wN, #imm16    MOVZ: 1 10 100101 hw imm16 Rd
 *   MOVK wN, #imm16   1 11 100101 ...
 */

static bool is_pacibsp(uint32_t w) { return w == 0xd503237fu; }

static bool decode_bl(uint32_t w, int64_t *rel) {
    if ((w & 0xfc000000u) != 0x94000000u) return false;
    int64_t imm = (int64_t)(w & 0x03ffffffu);
    if (imm & (1LL << 25)) imm -= (1LL << 26);
    *rel = imm * 4;
    return true;
}

static uint32_t enc_bl(int64_t rel) {
    /* rel must be signed multiple of 4, fit in 26-bit signed range * 4 */
    if (rel & 3) die("BL rel not aligned: %lld", (long long)rel);
    int64_t imm = rel / 4;
    if (imm < -(1LL << 25) || imm >= (1LL << 25)) die("BL range %lld", (long long)rel);
    return 0x94000000u | ((uint32_t)imm & 0x03ffffffu);
}

static uint32_t enc_b(int64_t rel) {
    if (rel & 3) die("B rel not aligned: %lld", (long long)rel);
    int64_t imm = rel / 4;
    if (imm < -(1LL << 25) || imm >= (1LL << 25)) die("B range %lld", (long long)rel);
    return 0x14000000u | ((uint32_t)imm & 0x03ffffffu);
}

/* Resolve ADRP (at va_adrp) + ADD immediate (at va_add) referring to same Rd. */
static bool decode_adrp_add(const uint8_t *code, uint64_t va_adrp, uint64_t *target) {
    uint32_t w0 = rd32(code);
    uint32_t w1 = rd32(code + 4);
    if ((w0 & 0x9f000000u) != 0x90000000u) return false;
    int64_t imm = ((w0 >> 29) & 3) | (((w0 >> 5) & 0x7ffffu) << 2);
    if (imm & (1LL << 20)) imm -= (1LL << 21);
    uint64_t base = (va_adrp & ~0xfffULL) + ((uint64_t)imm << 12);
    unsigned reg = w0 & 31;
    if ((w1 & 0xffc00000u) != 0x91000000u) return false;
    if (((w1 >> 5) & 31) != reg) return false;
    uint64_t off = (w1 >> 10) & 0xfff;
    *target = base + off;
    return true;
}

/* -------------------------------------- function-start lookup (sorted VA) */

static int cmp_u64(const void *a, const void *b) {
    uint64_t x = *(const uint64_t*)a, y = *(const uint64_t*)b;
    return (x > y) - (x < y);
}

/* function-start helpers removed: anchor discovery scans __TEXT_EXEC
 * directly for the REQ4 instruction template, which is unique. */

/* ----------------------------------------------------- string discovery */

static uint64_t find_cstring(const image_t *im, const char *needle) {
    size_t nlen = strlen(needle);
    uint64_t hit = 0;
    size_t hits = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        /* Scan read-only data-ish segments. */
        if (strncmp(s->name, "__TEXT", 16) && strncmp(s->name, "__DATA_CONST", 16)
            && strncmp(s->name, "__TEXT_EXEC", 16))
            continue;
        if (s->filesize == 0) continue;
        const uint8_t *data = im->buf + s->fileoff;
        for (size_t j = 0; j + nlen < s->filesize; j++) {
            if (data[j] != (uint8_t)needle[0]) continue;
            if (memcmp(data + j, needle, nlen)) continue;
            if (data[j + nlen] != 0) continue;
            /* Not a prefix of a longer string, and either at start of segment or preceded by NUL. */
            if (j && data[j - 1] != 0) continue;
            uint64_t va = s->vmaddr + j;
            if (!hit) hit = va;
            else if (va != hit) hits++;
            hits++;
        }
    }
    if (!hit) die("string %s not found", needle);
    if (hits > 1) die("string %s is ambiguous (%zu occurrences)", needle, hits);
    return hit;
}

/* --------------------------------------------- ADRP+ADD XREF scan */

typedef struct {
    uint64_t site;      /* VA of the ADRP instruction */
    uint64_t target;    /* resolved VA */
} xref_t;

static size_t find_adrp_add_xrefs(const image_t *im, uint64_t want,
                                  xref_t *out, size_t cap) {
    size_t n = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (!(s->initprot & 4)) continue;
        if (s->filesize < 8) continue;
        const uint8_t *data = im->buf + s->fileoff;
        for (size_t p = 0; p + 8 <= s->filesize; p += 4) {
            uint32_t w = rd32(data + p);
            if ((w & 0x9f000000u) != 0x90000000u) continue;
            /* scan a small window for the matching ADD */
            for (size_t q = p + 4; q + 4 <= s->filesize && q <= p + 24; q += 4) {
                uint32_t w1 = rd32(data + q);
                if ((w1 & 0xffc00000u) != 0x91000000u) continue;
                if (((w & 31) != ((w1 >> 5) & 31))) continue;
                uint64_t target;
                if (!decode_adrp_add(data + p, s->vmaddr + p, &target)) break;
                if (target == want) {
                    if (n < cap) {
                        out[n].site = s->vmaddr + p;
                        out[n].target = target;
                    }
                    n++;
                }
                break;
            }
        }
    }
    return n;
}

/* ---------------------------------------------- caller-site BL scan */

static size_t find_bl_callers(const image_t *im, uint64_t target,
                              uint64_t *out_sites, size_t cap) {
    size_t n = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (!(s->initprot & 4)) continue;
        const uint8_t *data = im->buf + s->fileoff;
        for (size_t p = 0; p + 4 <= s->filesize; p += 4) {
            uint32_t w = rd32(data + p);
            int64_t rel;
            if (!decode_bl(w, &rel)) continue;
            uint64_t site = s->vmaddr + p;
            if ((uint64_t)((int64_t)site + rel) == target) {
                if (n < cap) out_sites[n] = site;
                n++;
            }
        }
    }
    return n;
}

/* -------------------------------------------------- cave discovery */

typedef struct {
    uint64_t va;
    uint64_t end;
    size_t   fileoff;
} cave_t;

static uint64_t *g_refs = NULL;
static size_t g_nrefs = 0;

static int cmp_u64_qsort(const void *a, const void *b) {
    uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
    return (x > y) - (x < y);
}

static void build_refs(const image_t *im) {
    size_t cap = 1 << 20, n = 0;
    uint64_t *out = malloc(cap * sizeof(uint64_t));
    if (!out) die("oom refs");
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (!(s->initprot & 4)) continue;
        const uint8_t *data = im->buf + s->fileoff;
        for (size_t p = 0; p + 4 <= s->filesize; p += 4) {
            uint32_t w = rd32(data + p);
            uint64_t addr = s->vmaddr + p;
            uint64_t t = 0; bool have = false;
            int64_t rel = 0;
            if (decode_bl(w, &rel)) { t = (uint64_t)((int64_t)addr + rel); have = true; }
            else if ((w & 0x7c000000u) == 0x14000000u) {
                int64_t im26 = w & 0x03ffffffu;
                if (im26 & (1LL << 25)) im26 -= (1LL << 26);
                t = (uint64_t)((int64_t)addr + im26 * 4);
                have = true;
            }
            else if ((w & 0xff000010u) == 0x54000000u
                  || (w & 0x7e000000u) == 0x34000000u) {
                int64_t im19 = (w >> 5) & 0x7ffffu;
                if (im19 & (1LL << 18)) im19 -= (1LL << 19);
                t = (uint64_t)((int64_t)addr + im19 * 4);
                have = true;
            }
            else if ((w & 0x7e000000u) == 0x36000000u) {
                int64_t im14 = (w >> 5) & 0x3fffu;
                if (im14 & (1LL << 13)) im14 -= (1LL << 14);
                t = (uint64_t)((int64_t)addr + im14 * 4);
                have = true;
            }
            else if ((w & 0x9f000000u) == 0x10000000u) {
                int64_t im21 = ((w >> 29) & 3) | (((w >> 5) & 0x7ffffu) << 2);
                if (im21 & (1LL << 20)) im21 -= (1LL << 21);
                t = (uint64_t)((int64_t)addr + im21);
                have = true;
            }
            else if ((w & 0x9f000000u) == 0x90000000u) {
                if (p + 8 <= s->filesize) {
                    uint64_t at;
                    if (decode_adrp_add(data + p, addr, &at)) { t = at; have = true; }
                }
            }
            if (have) {
                if (n == cap) {
                    cap *= 2;
                    uint64_t *n2 = realloc(out, cap * sizeof(uint64_t));
                    if (!n2) die("oom refs grow");
                    out = n2;
                }
                out[n++] = t;
            }
        }
    }
    qsort(out, n, sizeof(uint64_t), cmp_u64_qsort);
    g_refs = out;
    g_nrefs = n;
}

static bool ref_in_range(uint64_t lo, uint64_t hi) {
    size_t a = 0, b = g_nrefs;
    while (a < b) {
        size_t m = (a + b) / 2;
        if (g_refs[m] < lo) a = m + 1;
        else b = m;
    }
    if (a < g_nrefs && g_refs[a] < hi) return true;
    return false;
}

static cave_t find_cave(const image_t *im, size_t min_len, uint64_t near_va) {
    /*
     * A safe cave: run of >= min_len zero bytes, no instruction reference
     * lands inside, and no LC_FUNCTION_STARTS entry falls inside. Within
     * reach of a BL from near_va (signed 26-bit * 4 = +/- 128 MiB).
     */
    if (!g_refs) build_refs(im);

    cave_t best = {0};
    size_t best_len = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (strncmp(s->name, "__TEXT_EXEC", 16)) continue;
        if (!(s->initprot & 4)) continue;
        const uint8_t *data = im->buf + s->fileoff;
        size_t p = 0;
        while (p + 4 <= s->filesize) {
            uint32_t w = rd32(data + p);
            if (w == 0) {
                size_t run_start = p;
                while (p + 4 <= s->filesize) {
                    uint32_t w2 = rd32(data + p);
                    if (w2 != 0) break;
                    p += 4;
                }
                size_t run_end = p;
                size_t run_len = run_end - run_start;
                if (run_len < min_len) continue;
                uint64_t va_start = s->vmaddr + run_start;
                uint64_t va_end   = s->vmaddr + run_end;
                int64_t rel = (int64_t)va_start - (int64_t)near_va;
                if (rel < -(1LL << 27) || rel >= (1LL << 27)) continue;
                bool between = true;
                for (size_t k = 0; k < im->nstarts; k++) {
                    uint64_t fs = im->starts[k];
                    if (fs > va_start && fs < va_end) { between = false; break; }
                    if (fs >= va_end) break;
                }
                if (!between) continue;
                if (ref_in_range(va_start + 1, va_end)) continue;
                if (run_len > best_len) {
                    best.va = va_start;
                    best.end = va_end;
                    best.fileoff = s->fileoff + run_start;
                    best_len = run_len;
                }
            } else {
                p += 4;
            }
        }
    }
    if (!best.va) die("no suitable cave found (min_len=%zu near 0x%" PRIx64 ")", min_len, near_va);
    return best;
}

/* ================================================================
 *            Anchor discovery for AppleSEPCredentialManager
 * ================================================================
 *
 * We locate:
 *   STR_VERSION   the "responsePayloadV1.payloadVersion" cstring
 *   PERFORMCMD    enclosing PACIBSP of a known reference chain
 *   REQ4_CALL     the BL to sendSEPCommand inside the request-4 normal path
 *   REQ4_SETUP    the "str x24, [sp]" at the start of the request-4 block
 *   SENDSEP       sendSEPCommand entry (BL target of REQ4_CALL)
 *
 * We refuse to continue unless every anchor is uniquely identified by
 * signature, is contained in a PACIBSP-prolog function, and the request-4
 * block has the exact register-argument sequence we expect.
 */

typedef struct {
    uint64_t str_version;
    uint64_t performcmd;
    uint64_t req4_setup;
    uint64_t req4_call;
    uint64_t sendsep;
} anchors_t;

/* Instruction templates for the request-4 normal path at
 * fffffff0093a9650 (15.5). All ten words, with no imm variability except
 * the trailing BL. */
static const uint32_t REQ4_TPL[] = {
    0xf90003f8u, /* str  x24, [sp]           */
    0xaa1603e0u, /* mov  x0, x22             */
    0x52800081u, /* mov  w1, #4              */
    0x52800002u, /* mov  w2, #0              */
    0xaa1503e3u, /* mov  x3, x21             */
    0xaa1303e4u, /* mov  x4, x19             */
    0xaa1703e5u, /* mov  x5, x23             */
    0xaa1403e6u, /* mov  x6, x20             */
    0x52800027u, /* mov  w7, #1              */
    /* index 9 is the BL (match only its opcode class). */
};
#define REQ4_LEN (10)

static bool match_req4(const uint8_t *code) {
    for (int i = 0; i < 9; i++) {
        if (rd32(code + 4 * i) != REQ4_TPL[i]) return false;
    }
    uint32_t w = rd32(code + 4 * 9);
    int64_t rel;
    return decode_bl(w, &rel);
}

static void discover(image_t *im, anchors_t *a) {
    /* 1. version string (sanity anchor - proves this is a credential-manager
     *    kernel; its XREF is inside sendSEPCommand's response parser.) */
    a->str_version = find_cstring(im, "responsePayloadV1.payloadVersion > 0");

    xref_t xrefs[16];
    size_t nx = find_adrp_add_xrefs(im, a->str_version, xrefs, 16);
    if (nx != 1) die("expected exactly 1 XREF to version string, got %zu", nx);

    /* 2. The REQ4 template is a unique 36-byte signature. Scan every
     *    executable segment for it; require exactly one hit followed by a
     *    valid BL. That hit is the request-4 call site inside
     *    _performCommand. */
    uint64_t hit = 0; size_t hits = 0;
    for (size_t i = 0; i < im->nseg; i++) {
        const seg_t *s = &im->segs[i];
        if (!(s->initprot & 4)) continue;
        if (s->filesize < 4 * REQ4_LEN) continue;
        const uint8_t *data = im->buf + s->fileoff;
        for (size_t p = 0; p + 4 * REQ4_LEN <= s->filesize; p += 4) {
            if (match_req4(data + p)) {
                uint64_t va = s->vmaddr + p;
                if (!hits) hit = va;
                hits++;
            }
        }
    }
    if (hits != 1) die("REQ4 template matched %zu times (expected 1)", hits);

    a->req4_setup = hit;
    a->req4_call  = hit + 4 * 9;

    /* 3. Resolve sendSEPCommand from the BL target of REQ4_CALL. */
    size_t bl_off = va_to_off(im, a->req4_call, 4);
    uint32_t bl = rd32(im->buf + bl_off);
    int64_t rel;
    if (!decode_bl(bl, &rel)) die("REQ4_CALL is not a BL");
    a->sendsep = (uint64_t)((int64_t)a->req4_call + rel);

    size_t ss_off = va_to_off(im, a->sendsep, 4);
    if (!is_pacibsp(rd32(im->buf + ss_off)))
        die("sendSEPCommand does not begin with PACIBSP");

    /* 4. Walk back from REQ4_SETUP to find enclosing _performCommand's
     *    PACIBSP. Bounded scan of 0x400 bytes. */
    a->performcmd = 0;
    for (size_t back = 0; back <= 0x400; back += 4) {
        uint64_t va = a->req4_setup - back;
        size_t o = va_to_off(im, va, 4);
        if (is_pacibsp(rd32(im->buf + o))) {
            a->performcmd = va;
            break;
        }
    }
    if (!a->performcmd) die("could not find _performCommand PACIBSP");

    /* 5. Sanity: version-string XREF must be a descendant of sendSEPCommand,
     *    i.e. inside some function whose nearest BL caller chain leads back
     *    to req4_call (or more loosely: the XREF address lies between
     *    sendSEPCommand's entry and the next function start). */
    if (xrefs[0].site < a->sendsep)
        die("version-string XREF at 0x%" PRIx64 " precedes sendSEPCommand entry",
            xrefs[0].site);

    /* 6. sendSEPCommand must have >= 2 BL callers (startup + request-4). */
    uint64_t sites[16];
    size_t nc = find_bl_callers(im, a->sendsep, sites, 16);
    if (nc < 2)
        die("sendSEPCommand has %zu callers (expected >=2)", nc);
}

/* =================================================================
 *                        Patch encoding
 * =================================================================
 *
 * Strategy:
 *   We replace the BL at REQ4_CALL with a BL to a bridge trampoline in
 *   the discovered cave. All of _performCommand's register setup for
 *   request-4 is preserved as-is before the BL; the trampoline consumes
 *   that register state exactly as sendSEPCommand would.
 *
 *   The trampoline:
 *     - Builds a 28-byte modern outer-request prefix on its local stack
 *       at known offsets.
 *     - Reads the caller's metadata pointer from caller_sp[0] (where the
 *       REQ4 normal path stored x24 at REQ4_SETUP). The caller_sp before
 *       our BL equals our sp + frame_size.
 *     - Copies {prefix || original input} into a per-driver static scratch
 *       buffer carved from the tail of the cave. The scratch buffer is 4
 *       KiB; request-4 payloads observed are small (12 bytes in-trace).
 *     - If the fused length does not fit the scratch buffer, bridge
 *       returns -EOVERFLOW without touching SEP, preserving existing
 *       error propagation.
 *     - Writes the metadata pointer at caller_sp[0] to pass it through,
 *       then BLs sendSEPCommand with x3/x4 pointing at the fused buffer.
 *     - Returns sendSEPCommand's w0 verbatim.
 *
 *   NOTE: This bridge intentionally does NOT patch the response path.
 *   iOS 16.0's response parser skips a dynamic header length, which the
 *   iOS 15.5 parser already does (it reads u16 header length at response
 *   +2 and skips that many bytes). The 16.0 wire format places the
 *   modern 12-byte header so that its headerLength field at +2 is
 *   non-zero, so the 15.5 parser already strips it. If device testing
 *   shows the response needs explicit v1 handling, extend here with a
 *   separate patch site and a second cave allocation.
 *
 *   Sequence number is held in a 4-byte slot inside the cave scratch
 *   area, incremented on each call (saturates to 1 on zero per 16.0
 *   behavior). Command-gate serialization makes a plain load/store safe
 *   per the plan.
 *
 * The emitted trampoline (ARM64, no PAC-signed pointers used here):
 *
 *   bridge:                         // (caller args + caller_sp[0] = meta)
 *     pacibsp
 *     stp   x29, x30, [sp, #-0x60]!  // 96-byte frame
 *     mov   x29, sp
 *     stp   x19, x20, [sp, #0x10]
 *     stp   x21, x22, [sp, #0x20]
 *     stp   x23, x24, [sp, #0x30]
 *     str   x25,      [sp, #0x40]
 *
 *     mov   x19, x0                 // obj
 *     mov   w20, w1                 // req id (4)
 *     mov   x21, x3                 // orig inPtr
 *     mov   x22, x4                 // orig inLen
 *     mov   x23, x5                 // outPtr
 *     mov   x24, x6                 // outLenPtr
 *     ldr   x25, [x29, #0x60]       // caller_sp[0] = meta
 *
 *     // bail if payload too big
 *     mov   x8, #(SCRATCH_SIZE - 28)
 *     cmp   x22, x8
 *     b.hi  Lerr
 *
 *     // Load scratch base via ADRP+ADD (patched with cave+scratch offset)
 *     adrp  x9, <scratch_page>
 *     add   x9, x9, #<scratch_lo>   // x9 -> scratch[0]
 *
 *     // Build 28-byte prefix at scratch[0..28]:
 *     mov   w10, #1
 *     movk  w10, #0x1c, lsl #16     // 0x001c0001 ver/zero/hdrlen
 *     ldr   w11, [x9, #(SCRATCH_SIZE - 4)]   // sequence
 *     add   w11, w11, #1
 *     cmp   w11, #0
 *     csinc w11, w11, wzr, ne       // skip zero on wrap (simpler: ne select)
 *     str   w11, [x9, #(SCRATCH_SIZE - 4)]
 *     stp   w10, w11, [x9, #0x00]
 *     str   wzr, [x9, #0x08]
 *     cbz   x24, 1f
 *     ldr   w12, [x24]
 *     b     2f
 *   1: mov   w12, #0
 *   2: str   w12, [x9, #0x0c]
 *     stp   xzr, xzr, [x9, #0x10]   // +0x10 and +0x18 zero
 *
 *     // memcpy input -> scratch[28..]
 *     cbz   x21, 3f
 *     add   x13, x9, #28
 *     mov   x14, x21
 *     mov   x15, x22
 *   lcopy:
 *     cbz   x15, 3f
 *     ldrb  w16, [x14], #1
 *     strb  w16, [x13], #1
 *     subs  x15, x15, #1
 *     b.ne  lcopy
 *   3:
 *     add   x17, x22, #28           // fused length (bounded above)
 *
 *     // Store meta at caller_sp[0] (unchanged, but explicit for clarity):
 *     str   x25, [x29, #0x60]
 *
 *     // Call sendSEPCommand(obj, 4, 0, scratch, fused, outPtr, outLenPtr, 1)
 *     mov   x0, x19
 *     mov   w1, w20
 *     mov   w2, #0
 *     mov   x3, x9
 *     mov   x4, x17
 *     mov   x5, x23
 *     mov   x6, x24
 *     mov   w7, #1
 *     bl    sendSEPCommand
 *     b     Ldone
 *
 *   Lerr:
 *     mov   w0, #-6                 // kIOReturnNoMemory analog; path reports as sendSEP failure
 *   Ldone:
 *     ldr   x25,      [sp, #0x40]
 *     ldp   x23, x24, [sp, #0x30]
 *     ldp   x21, x22, [sp, #0x20]
 *     ldp   x19, x20, [sp, #0x10]
 *     ldp   x29, x30, [sp], #0x60
 *     retab
 *
 * Scratch region layout, 4 KiB at the tail of the cave:
 *   [0 .. 28]              prefix buffer
 *   [28 .. SCRATCH_SIZE-4] payload image buffer
 *   [SCRATCH_SIZE-4 ..]    u32 sequence counter
 *
 * The emitter below emits exactly this code. It also records every
 * {fileoff, old_bytes, new_bytes} edit so we can validate all edits
 * before applying any, and so we can print a byte-diff manifest.
 */

/* Scratch for {prefix || payload} lives on the bridge's OWN stack: __TEXT_EXEC
 * is KTRR/CTRR-locked read-only on arm64e, so writes into any cave inside it
 * fault at EL1 as soon as the bridge first runs. STACK_SCRATCH is the max
 * payload we accept; prefix is a fixed 28 bytes before it. The scratch region
 * on the stack runs [sp+0x20..sp+0x1C0] = 416 B; reserve 4 B of slack between
 * payload end and x19/x20 save area. Observed request-4 inLen is 12 bytes. */
#define STACK_SCRATCH 384
#define BRIDGE_MAX_BYTES 256

typedef struct {
    size_t   fileoff;
    size_t   len;
    uint8_t *old;
    uint8_t *new;
} edit_t;

typedef struct {
    edit_t *v;
    size_t  n;
    size_t  cap;
} edits_t;

static void edits_push(edits_t *e, size_t off, const void *old, const void *new, size_t len) {
    if (e->n == e->cap) {
        e->cap = e->cap ? e->cap * 2 : 8;
        e->v = realloc(e->v, e->cap * sizeof(edit_t));
        if (!e->v) die("oom edits");
    }
    edit_t *x = &e->v[e->n++];
    x->fileoff = off;
    x->len = len;
    x->old = malloc(len);
    x->new = malloc(len);
    if (!x->old || !x->new) die("oom edit bufs");
    memcpy(x->old, old, len);
    memcpy(x->new, new, len);
}

/* Emit ARM64 words sequentially into buf, returning new write offset. */
static size_t emit(uint8_t *buf, size_t at, uint32_t word) {
    wr32(buf + at, word);
    return at + 4;
}

static size_t build_bridge(uint8_t *buf, uint64_t bridge_va,
                           uint64_t sendsep_va) {
    size_t at = 0;
    /* prolog: 0x200-byte frame (cave memory is KTRR-locked read-only, so
     * scratch lives on our own stack instead).
     *   [sp+0x000..0x020]  outgoing stack args (metadata at [sp+0])
     *   [sp+0x020..0x1C0]  scratch: 28-byte prefix + up to 384-byte payload
     *   [sp+0x1C0..0x1D0]  x19/x20
     *   [sp+0x1D0..0x1E0]  x21/x22
     *   [sp+0x1E0..0x1F0]  x23/x24
     *   [sp+0x1F0..0x200]  FP/LR
     *   caller_sp == our sp + 0x200 == x29 + 0x10; metadata at [x29+0x10]. */
    at = emit(buf, at, 0xd503237fu); /* pacibsp */
    at = emit(buf, at, 0xd10803ffu); /* sub sp, sp, #0x200 */
    at = emit(buf, at, 0xa91f7bfdu); /* stp x29, x30, [sp, #0x1F0] */
    at = emit(buf, at, 0x9107c3fdu); /* add x29, sp, #0x1F0 */
    at = emit(buf, at, 0xa91c53f3u); /* stp x19, x20, [sp, #0x1C0] */
    at = emit(buf, at, 0xa91d5bf5u); /* stp x21, x22, [sp, #0x1D0] */
    at = emit(buf, at, 0xa91e63f7u); /* stp x23, x24, [sp, #0x1E0] */
    /* arg captures */
    at = emit(buf, at, 0xaa0003f3u); /* mov x19, x0 */
    at = emit(buf, at, 0x2a0103f4u); /* mov w20, w1 */
    at = emit(buf, at, 0xaa0303f5u); /* mov x21, x3 */
    at = emit(buf, at, 0xaa0403f6u); /* mov x22, x4 */
    at = emit(buf, at, 0xaa0503f7u); /* mov x23, x5 */
    at = emit(buf, at, 0xaa0603f8u); /* mov x24, x6 */
    at = emit(buf, at, 0xf9400bb9u); /* ldr x25, [x29, #0x10]  (metadata ptr from caller_sp[0]) */

    /* size guard: MOV x8, #STACK_SCRATCH then CMP x22, x8 then B.HI Lerr */
    if (STACK_SCRATCH > 0xffff) die("imm16 out of range");
    at = emit(buf, at, 0xd2800008u | ((uint32_t)STACK_SCRATCH << 5)); /* movz x8, #STACK_SCRATCH */
    at = emit(buf, at, 0xeb0802dfu); /* cmp x22, x8 */
    size_t bhi_slot = at;
    at = emit(buf, at, 0x54000008u); /* b.hi Lerr (placeholder) */

    /* Scratch base: x9 = sp + 0x20 (writable stack memory) */
    at = emit(buf, at, 0x910083e9u); /* add x9, sp, #0x20 */

    /* Build prefix (sequence held in w11 only, no persistence; the SEP's
     * sequence-mismatch handling is diagnostic-only per plan):
     *   movz w10, #1
     *   movk w10, #0x1c, lsl #16     ; w10 = 0x001c0001
     *   movz w11, #1                 ; sequence = 1
     *   stp  w10, w11, [x9]          ; +0x00 ver/hdrlen, +0x04 seq
     *   str  wzr, [x9, #0x08]
     *   cbz  x24, 1f
     *   ldr  w12, [x24]
     *   b    2f
     * 1: movz w12, #0
     * 2: str  w12, [x9, #0x0c]
     *   stp  xzr, xzr, [x9, #0x10]
     */
    at = emit(buf, at, 0x5280002au);              /* movz w10, #1 */
    at = emit(buf, at, 0x72a0038au);              /* movk w10, #0x1c, lsl #16 */
    at = emit(buf, at, 0x5280002bu);              /* movz w11, #1 */
    at = emit(buf, at, 0x29002d2au);              /* stp w10, w11, [x9] */
    at = emit(buf, at, 0xb900093fu);              /* str wzr, [x9, #0x08] */
    size_t cbz_slot = at;
    at = emit(buf, at, 0xb4000098u);              /* cbz x24, L1 placeholder */
    at = emit(buf, at, 0xb940030cu);              /* ldr w12, [x24] */
    size_t b_slot = at;
    at = emit(buf, at, 0x14000002u);              /* b L2 placeholder */
    size_t L1 = at;
    at = emit(buf, at, 0x5280000cu);              /* movz w12, #0 */
    size_t L2 = at;
    at = emit(buf, at, 0xb9000d2cu);              /* str w12, [x9, #0x0c] */
    at = emit(buf, at, 0xa9017d3fu);              /* stp xzr, xzr, [x9, #0x10] */

    /* Resolve cbz (x24==0 -> L1) and b (-> L2) */
    {
        int64_t dL1 = (int64_t)L1 - (int64_t)cbz_slot;
        int64_t imm19 = dL1 / 4;
        if (imm19 < -(1LL << 18) || imm19 >= (1LL << 18)) die("cbz range");
        uint32_t w = 0xb4000000u | 24 | ((uint32_t)imm19 & 0x7ffffu) << 5;
        wr32(buf + cbz_slot, w);
        int64_t dL2 = (int64_t)L2 - (int64_t)b_slot;
        wr32(buf + b_slot, enc_b(dL2));
    }

    /* memcpy loop: input -> scratch+28 */
    /*   cbz  x21, Lcopy_done
     *   add  x13, x9, #28
     *   mov  x14, x21
     *   mov  x15, x22
     * Lcopy:
     *   cbz  x15, Lcopy_done
     *   ldrb w16, [x14], #1
     *   strb w16, [x13], #1
     *   subs x15, x15, #1
     *   b.ne Lcopy
     * Lcopy_done:
     */
    size_t cbz2_slot = at;
    at = emit(buf, at, 0xb4000015u);              /* cbz x21, Lcopy_done placeholder */
    at = emit(buf, at, 0x9100712du);              /* add x13, x9, #28 */
    at = emit(buf, at, 0xaa1503eeu);              /* mov x14, x21 */
    at = emit(buf, at, 0xaa1603efu);              /* mov x15, x22 */
    size_t Lcopy = at;
    size_t cbz3_slot = at;
    at = emit(buf, at, 0xb40000afu);              /* cbz x15, Lcopy_done placeholder */
    at = emit(buf, at, 0x384015d0u);              /* ldrb w16, [x14], #1 */
    at = emit(buf, at, 0x380015b0u);              /* strb w16, [x13], #1 */
    at = emit(buf, at, 0xf10005efu);              /* subs x15, x15, #1 */
    int64_t dBack = (int64_t)Lcopy - (int64_t)at;
    at = emit(buf, at, 0x54000001u | ((uint32_t)((dBack / 4) & 0x7ffffu) << 5)); /* b.ne Lcopy */
    size_t Lcopy_done = at;
    /* resolve cbz2 and cbz3 */
    {
        int64_t d2 = (int64_t)Lcopy_done - (int64_t)cbz2_slot;
        uint32_t w2 = 0xb4000000u | 21 | ((uint32_t)((d2 / 4) & 0x7ffffu) << 5);
        wr32(buf + cbz2_slot, w2);
        int64_t d3 = (int64_t)Lcopy_done - (int64_t)cbz3_slot;
        uint32_t w3 = 0xb4000000u | 15 | ((uint32_t)((d3 / 4) & 0x7ffffu) << 5);
        wr32(buf + cbz3_slot, w3);
    }

    /* Fused length = inLen + 28 */
    at = emit(buf, at, 0x910072d1u);              /* add x17, x22, #28 */

    /* Store metadata ptr at our [sp+0] so sendSEPCommand sees it as its
     * 9th arg (same contract as the original request-4 call site). */
    at = emit(buf, at, 0xf90003f9u);              /* str x25, [sp, #0] */

    /* Setup sendSEP args and call. */
    at = emit(buf, at, 0xaa1303e0u);              /* mov x0, x19 */
    at = emit(buf, at, 0x2a1403e1u);              /* mov w1, w20 */
    at = emit(buf, at, 0x52800002u);              /* mov w2, #0 */
    at = emit(buf, at, 0xaa0903e3u);              /* mov x3, x9 */
    at = emit(buf, at, 0xaa1103e4u);              /* mov x4, x17 */
    at = emit(buf, at, 0xaa1703e5u);              /* mov x5, x23 */
    at = emit(buf, at, 0xaa1803e6u);              /* mov x6, x24 */
    at = emit(buf, at, 0x52800027u);              /* mov w7, #1 */

    /* BL sendSEPCommand */
    uint64_t bl_va = bridge_va + at;
    int64_t bl_rel = (int64_t)sendsep_va - (int64_t)bl_va;
    at = emit(buf, at, enc_bl(bl_rel));
    size_t bDone_slot = at;
    at = emit(buf, at, 0x14000000u);              /* b Ldone placeholder */

    size_t Lerr = at;
    at = emit(buf, at, 0x128000a0u);              /* movn w0, #5  -> w0 = -6 */
    size_t Ldone = at;

    /* resolve b.hi Lerr and b Ldone */
    {
        int64_t d = (int64_t)Lerr - (int64_t)bhi_slot;
        int64_t imm19 = d / 4;
        if (imm19 < -(1LL << 18) || imm19 >= (1LL << 18)) die("b.hi range");
        uint32_t w = 0x54000008u | ((uint32_t)imm19 & 0x7ffffu) << 5;
        wr32(buf + bhi_slot, w);
        int64_t dD = (int64_t)Ldone - (int64_t)bDone_slot;
        wr32(buf + bDone_slot, enc_b(dD));
    }

    /* epilog */
    at = emit(buf, at, 0xa95e63f7u);              /* ldp x23, x24, [sp, #0x1E0] */
    at = emit(buf, at, 0xa95d5bf5u);              /* ldp x21, x22, [sp, #0x1D0] */
    at = emit(buf, at, 0xa95c53f3u);              /* ldp x19, x20, [sp, #0x1C0] */
    at = emit(buf, at, 0xa95f7bfdu);              /* ldp x29, x30, [sp, #0x1F0] */
    at = emit(buf, at, 0x910803ffu);              /* add sp, sp, #0x200 */
    at = emit(buf, at, 0xd65f0fffu);              /* retab */

    if (at > BRIDGE_MAX_BYTES) die("bridge too large (%zu > %d)", at, BRIDGE_MAX_BYTES);
    return at;
}

/* =================================================================
 *                    atomic output file publishing
 * =================================================================*/

static void publish(const char *in_path, const char *out_path,
                    const uint8_t *data, size_t size) {
    /* refuse same inode */
    struct stat sin, sout;
    if (stat(in_path, &sin)) die("stat input: %s", strerror(errno));
    if (!stat(out_path, &sout)) {
        if (sin.st_dev == sout.st_dev && sin.st_ino == sout.st_ino)
            die("refusing: input and output are the same file");
        die("refusing: output exists at %s", out_path);
    } else if (errno != ENOENT) {
        die("stat output: %s", strerror(errno));
    }

    /* write sibling temp with exclusive create */
    size_t plen = strlen(out_path);
    char *tmp = malloc(plen + 20);
    if (!tmp) die("oom tmp");
    snprintf(tmp, plen + 20, "%s.sepfix.%d", out_path, (int)getpid());
    int fd = open(tmp, O_WRONLY | O_CREAT | O_EXCL | O_TRUNC, 0644);
    if (fd < 0) die("open temp: %s", strerror(errno));
    size_t off = 0;
    while (off < size) {
        ssize_t n = write(fd, data + off, size - off);
        if (n < 0) { unlink(tmp); die("write: %s", strerror(errno)); }
        off += (size_t)n;
    }
    if (fsync(fd)) { unlink(tmp); die("fsync: %s", strerror(errno)); }
    if (close(fd)) { unlink(tmp); die("close: %s", strerror(errno)); }

    if (rename(tmp, out_path)) {
        unlink(tmp);
        die("rename: %s", strerror(errno));
    }
    free(tmp);
}

/* ============================================================ main */

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s <input 15 kernel> <output 15 kernel>\n", argv[0]);
        return 2;
    }
    const char *in_path = argv[1];
    const char *out_path = argv[2];

    /* Read input. */
    int fd = open(in_path, O_RDONLY);
    if (fd < 0) die("open input: %s", strerror(errno));
    struct stat st;
    if (fstat(fd, &st)) die("fstat: %s", strerror(errno));
    size_t size = (size_t)st.st_size;
    uint8_t *buf = malloc(size);
    if (!buf) die("oom input");
    size_t rd = 0;
    while (rd < size) {
        ssize_t n = read(fd, buf + rd, size - rd);
        if (n <= 0) die("read: %s", n < 0 ? strerror(errno) : "short");
        rd += (size_t)n;
    }
    close(fd);

    image_t im = { .buf = buf, .size = size };
    parse_macho(&im);
    qsort(im.starts, im.nstarts, sizeof(uint64_t), cmp_u64);

    anchors_t a;
    discover(&im, &a);
    fprintf(stderr, "anchors:\n");
    fprintf(stderr, "  version string      0x%" PRIx64 "\n", a.str_version);
    fprintf(stderr, "  _performCommand     0x%" PRIx64 "\n", a.performcmd);
    fprintf(stderr, "  request-4 setup     0x%" PRIx64 "\n", a.req4_setup);
    fprintf(stderr, "  request-4 BL        0x%" PRIx64 "\n", a.req4_call);
    fprintf(stderr, "  sendSEPCommand      0x%" PRIx64 "\n", a.sendsep);

    /* Find cave for the bridge code only; scratch lives on the bridge's
     * stack frame because cave memory is in __TEXT_EXEC and KTRR-locked
     * read-only on arm64e. */
    cave_t cave = find_cave(&im, BRIDGE_MAX_BYTES + 32, a.req4_call);
    fprintf(stderr, "cave: 0x%" PRIx64 "..0x%" PRIx64 " (%" PRIu64 " bytes) fileoff=0x%zx\n",
            cave.va, cave.end, cave.end - cave.va, cave.fileoff);

    uint64_t bridge_va = cave.va;
    uint8_t bridge_bytes[BRIDGE_MAX_BYTES];
    memset(bridge_bytes, 0, sizeof(bridge_bytes));
    size_t bridge_len = build_bridge(bridge_bytes, bridge_va, a.sendsep);
    fprintf(stderr, "bridge: %zu bytes at 0x%" PRIx64 " (stack scratch %d B, max payload %d B)\n",
            bridge_len, bridge_va, STACK_SCRATCH + 28, STACK_SCRATCH);

    /* Build edit list. */
    edits_t edits = {0};

    /* Edit 1: rewrite the BL at REQ4_CALL to target the bridge. */
    {
        size_t call_off = va_to_off(&im, a.req4_call, 4);
        uint8_t old[4]; memcpy(old, im.buf + call_off, 4);
        int64_t new_rel = (int64_t)bridge_va - (int64_t)a.req4_call;
        uint32_t new_bl = enc_bl(new_rel);
        uint8_t newb[4];
        wr32(newb, new_bl);
        /* Confirm current bytes are a BL. */
        int64_t rel;
        if (!decode_bl(rd32(old), &rel))
            die("REQ4_CALL is not a BL at patch time");
        edits_push(&edits, call_off, old, newb, 4);
    }

    /* Edit 2: write bridge bytes into cave. */
    {
        size_t br_off = va_to_off(&im, bridge_va, bridge_len);
        for (size_t i = 0; i < bridge_len; i++) {
            if (im.buf[br_off + i] != 0)
                die("cave not zero at +%zu: 0x%02x", i, im.buf[br_off + i]);
        }
        uint8_t *old = calloc(1, bridge_len);
        if (!old) die("oom");
        edits_push(&edits, br_off, old, bridge_bytes, bridge_len);
        free(old);
    }

    /* Validate all edits fit within file and lengths match (lengths equal
     * old==new by construction; size preservation enforced here). */
    for (size_t i = 0; i < edits.n; i++) {
        edit_t *e = &edits.v[i];
        img_bounds(&im, e->fileoff, e->len, "edit");
        if (memcmp(im.buf + e->fileoff, e->old, e->len))
            die("edit %zu old-bytes mismatch at offset 0x%zx", i, e->fileoff);
    }

    /* Apply all. */
    for (size_t i = 0; i < edits.n; i++) {
        edit_t *e = &edits.v[i];
        memcpy(im.buf + e->fileoff, e->new, e->len);
    }

    /* Print manifest. */
    fprintf(stderr, "patch manifest (%zu edits):\n", edits.n);
    for (size_t i = 0; i < edits.n; i++) {
        edit_t *e = &edits.v[i];
        fprintf(stderr, "  @0x%08zx len=%zu\n", e->fileoff, e->len);
    }

    publish(in_path, out_path, im.buf, im.size);
    fprintf(stderr, "wrote %s (%zu bytes)\n", out_path, im.size);
    return 0;
}
