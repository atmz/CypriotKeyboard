// Tier-c eval: minimal Hunspell CLI that mimics `hunspell -a` (ispell
// pipe protocol). Reads words from stdin, one per line, and writes:
//   *                              (correct word)
//   & <word> <count> 0: s1, s2, … (incorrect with suggestions)
//   # <word> 0                     (incorrect, no suggestions)
// followed by an empty line between inputs.
//
// Built from the project's vendored hunspell_src/ so the eval-baseline
// behavior matches the iOS extension's runtime exactly.
//
// Usage:
//   hunspell-cli <aff_path> <dic_path> < words.txt

#include <iostream>
#include <string>
#include <cstdio>
#include <cstdlib>
#include "hunspell.h"

int main(int argc, char** argv) {
    if (argc != 3) {
        std::fprintf(stderr, "usage: %s <aff_path> <dic_path>\n", argv[0]);
        return 2;
    }

    Hunhandle* hs = Hunspell_create(argv[1], argv[2]);
    if (!hs) {
        std::fprintf(stderr, "Hunspell_create failed for aff=%s dic=%s\n",
                     argv[1], argv[2]);
        return 3;
    }

    // Banner — matches `hunspell -a`'s opening line so the existing
    // pipe-protocol parser can ignore it uniformly.
    std::cout << "@(#) International Ispell-like (Hunspell vendored CLI)\n";
    std::cout.flush();

    std::string line;
    while (std::getline(std::cin, line)) {
        if (line.empty()) {
            std::cout << "\n";
            std::cout.flush();
            continue;
        }

        const char* word = line.c_str();
        int correct = Hunspell_spell(hs, word);

        if (correct) {
            std::cout << "*\n\n";
        } else {
            char** sugg_list = nullptr;
            int n = Hunspell_suggest(hs, &sugg_list, word);
            if (n > 0 && sugg_list != nullptr) {
                std::cout << "& " << word << " " << n << " 0: ";
                for (int i = 0; i < n; ++i) {
                    if (i > 0) std::cout << ", ";
                    std::cout << sugg_list[i];
                }
                std::cout << "\n\n";
                Hunspell_free_list(hs, &sugg_list, n);
            } else {
                std::cout << "# " << word << " 0\n\n";
            }
        }
        std::cout.flush();
    }

    Hunspell_destroy(hs);
    return 0;
}
