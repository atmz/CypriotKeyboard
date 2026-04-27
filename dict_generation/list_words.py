from collections import defaultdict 

files = ["aceras.csv","oof.csv","beatrixcrisis.csv","erykini.csv","kaisitree.csv"]


def generate_cy_list(files, threshold=5):
    # note to self -- instead of raw threshold, could only select words that appear in N different sources
    words = defaultdict(lambda: 0)

    for file in files:
        data = open('corpus/'+file, "r")
        for line in data:
            split_line = line.split()
            last="."
            for word in split_line:
                last=word

                word = ''.join(e for e in word if e.isalpha())
                if not last[-1].isalpha(): #conservatively, only lowercase if last letter of previous word is alphabetical
                    word=word.lower()
                if len(word)>1 and not((word[0]>='A' and word[0]<='Z') or (word[0]>='a' and word[0]<='z')):
                    words[word]+=1
        data.close()

    rank  = [(k, v) for k, v in words.items() if v>threshold]
    rank.sort(key=lambda a: a[0], reverse=False)
    #print(len(rank))
    #for r in rank:
    #        print(r[0])
    return [r[0] for r in rank]


def expand(word):
    result = []
    if word[-1]=='ω':
        stem = word

def generate_cy_list_2(files, threshold=20):
    # note to self -- instead of raw threshold, could only select words that appear in N different sources
    words = defaultdict(set)
    words_abs = defaultdict(lambda: 0)

    for file in files:
        data = open('corpus/'+file, "r")
        for line in data:
            split_line = line.split()
            last="."
            for word in split_line:
                word = ''.join(e for e in word if e.isalpha())
                if len(last)==0 or not last[-1].isalpha(): #conservatively, only lowercase if last letter of previous word is not alphabetical
                    word=word.lower()
                if len(word)>1 and not((word[0]>='A' and word[0]<='Z') or (word[0]>='a' and word[0]<='z')):
                    words[word].add(file)
                    words_abs[word]+=1
                last=word

        data.close()
    rank  = [k for k, v in words.items() if len(v)>2 and words_abs[k]>threshold]
   # rank2 = [k for k, v in words_abs.items() if v>threshold]
    rank3 = rank#+rank2
    rank3a = set(rank3)
    rank3b = []
    for word in rank3:
        if word==word.lower() or word.lower() not in rank3a:
            rank3b.append(word)
    rank3b.sort(key=lambda a: a, reverse=False)
    rank4 = [ w for w in rank3b if 
        (w!=w.upper()) 
    ]

    print(len(rank))
    print(len(rank4))
    #for r in rank:
    #        print(r[0])
    return [r for r in rank4]


def merge(list_of_lists):
    new = []
    for l in list_of_lists:
        new+=l
    new.sort()
    return new


words = generate_cy_list_2(files)

# Re-tokenize the corpus to capture absolute frequencies for ALL observed
# tokens, not just the filtered ones above. This output is used by the
# tier-c DAWG build to rank canonical-form collisions.
import json
from collections import defaultdict

corpus_freq = defaultdict(int)
for fname in files:
    with open('corpus/' + fname, encoding="utf-8") as f:
        for line in f:
            for raw in line.split():
                cleaned = ''.join(e for e in raw if e.isalpha())
                if not cleaned:
                    continue
                # Lowercase per the same heuristic used above
                cleaned = cleaned.lower()
                # Skip Latin tokens (English code-switching in blogs)
                if (cleaned[0] >= 'A' and cleaned[0] <= 'Z') or (cleaned[0] >= 'a' and cleaned[0] <= 'z'):
                    continue
                corpus_freq[cleaned] += 1

with open("corpus_freq.json", "w", encoding="utf-8") as f:
    json.dump(corpus_freq, f, ensure_ascii=False)
print(f"corpus_freq.json: {len(corpus_freq)} unique tokens")

# (existing) char count dump and word list write
char_counts = defaultdict(lambda: 0)
for w in words:
    for l in w:
        char_counts[l] += 1
cs = [(k, v) for k, v in char_counts.items()]
cs.sort(key=lambda a: a[1], reverse=False)
print([a[0] for a in cs])
word_list = "el_CY_words.v3.dic"
with open(word_list, "w", encoding="utf-8") as data:
    data.write(str(len(words)) + "\n")
    data.write("\n".join(words))
