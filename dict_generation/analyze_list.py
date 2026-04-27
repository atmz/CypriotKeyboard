from collections import defaultdict 

files = ["spyros_list.dic","corpus/aceras.csv","corpus/oof.csv","corpus/beatrixcrisis.csv","corpus/erykini.csv","corpus/kaisitree.csv","corpus/blogskepseon.csv","corpus/drprasinada.csv", "corpus/wikipriaka_wordlist.dic","corpus/pkios_lexeis.txt","magic_words.dic"]
greekfile = "el_GR/el_GR.dic"

greekwords = {}

def generate_greek_list():
        data = open(greekfile, "r")
        for line in data: 
            split_line = line.split()
            for word in split_line:
                greekwords[word]=1

def generate_analysis(files, threshold=10):
    generate_greek_list()
    # note to self -- instead of raw threshold, could only select words that appear in N different sources
    words = defaultdict(set)
    words_abs = defaultdict(lambda: 0)

    for file in files:
        data = open(file, "r")
        for line in data:
            split_line = line.split()
            last="."
            for word in split_line:
                word = ''.join(e for e in word if e.isalpha()or e==u'\u0301'or e==u'\u0306')
                if len(last)==0 or not last[-1].isalpha(): #conservatively, only lowercase if last letter of previous word is not alphabetical
                    word=word.lower()
                if len(word)>1 and not((word[0]>='A' and word[0]<='Z') or (word[0]>='a' and word[0]<='z')):
                    words[word].add(file)
                    words_abs[word]+=1
                last=word
        data.close()
    rank  = [k for k, v in words.items() if k not in greekwords and k==k.lower()]
    print (len(greekwords))
    print (len(words))
    print (len(rank))
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

    sheet = "analyze.csv"
    data = open(sheet, "w")
    data.write("word,")
    data.write(",".join(files))
    data.write("\n")
    for word in rank4:
        data.write(word+',')
        for file in files:
            if file in words[word]:
                data.write ("1,")
            else:
                data.write ("0,")
        data.write(str(len(words[word]))+",")
        data.write(str(words_abs[word]))
        data.write("\n")

    data.close()


words = generate_analysis(files)
