// tools/ram-check.c — does this PC's memory read back what was written? No disk and no hash: a fresh
// buffer each round, filled with random words of its own, read straight back, given back. Found the bad
// bit of 4 Nov 2026 (bit 61 on 8 CPUs, 10 wrong words in 673 GB: three copies, 16 MB buffers, 3 minutes;
// random data matters: stressapptest's own patterns passed 17 TB), behind wrong hashes and Btrfs errors.
//   gcc -O1 -o /tmp/ram-check tools/ram-check.c && /tmp/ram-check [SECONDS 600] [MB 16]
// Out: a line for each wrong word, then the verdict, the bits that flipped. Exit: 0 every word right · 1 not · 2 misuse
// A "right" counts for its size: at that rate 96 GB once passed by chance, so ask for 700 GB or more
// (three copies at once, ten minutes). Memtest86+ is the proof of a stick; this says whether to run it.
#define _GNU_SOURCE
#include <sched.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static inline uint64_t word(uint64_t seed, uint64_t i) {   // (splitmix64: every word its own, every bit in play)
    uint64_t z = seed + i * 0x9E3779B97F4A7C15ULL;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    return z ^ (z >> 27);
}

int main(int argc, char **argv) {
    double secs = argc > 1 ? atof(argv[1]) : 600;
    size_t mb = argc > 2 ? (size_t)atoi(argv[2]) : 16, n = (mb << 20) / sizeof(uint64_t);
    if (secs <= 0 || mb == 0) { fprintf(stderr, "usage: ram-check [SECONDS] [MB]\n"); return 2; }
    uint64_t rounds = 0, wrong = 0, bits[64] = {0};
    time_t t0 = time(NULL);
    while (difftime(time(NULL), t0) < secs) {
        volatile uint64_t *p = mmap(NULL, n * sizeof(uint64_t), PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
        if (p == MAP_FAILED) { perror("ram-check: mmap"); return 2; }
        uint64_t seed = rounds * 0x2545F4914F6CDD1DULL + (uint64_t)getpid();
        for (size_t i = 0; i < n; i++) p[i] = word(seed, i);
        for (size_t i = 0; i < n; i++) {
            uint64_t want = word(seed, i), got = p[i];
            if (got == want) continue;
            uint64_t x = got ^ want;
            wrong++;
            for (int b = 0; b < 64; b++) bits[b] += x >> b & 1;
            if (wrong <= 40)
                printf("round %llu cpu %d, byte %zu of its cache line: read %016llx, wrote %016llx, xor %016llx\n", (unsigned long long)rounds, sched_getcpu(),
                       i * sizeof(uint64_t) % 64, (unsigned long long)got, (unsigned long long)want, (unsigned long long)x);
            fflush(stdout);
        }
        munmap((void *)p, n * sizeof(uint64_t));
        rounds++;
    }
    double gb = (double)rounds * (double)mb / 1024;
    if (!wrong) { printf("right: every word of %.0f GB read back as written (%.0f s)\n", gb, difftime(time(NULL), t0)); return 0; }
    printf("WRONG: %llu words in %.0f GB read back differently (one in %.1f GB); the bits:", (unsigned long long)wrong, gb, gb / (double)wrong);
    for (int b = 0; b < 64; b++) if (bits[b]) printf(" %d (%llu times)", b, (unsigned long long)bits[b]);
    printf("\nThe same bit again and again is one stick's data line or cell: BIOS memory at its plain speed, then one stick at a time; Memtest86+ for the proof.\n");
    return 1;
}
