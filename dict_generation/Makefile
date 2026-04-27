clean:
	rm -f *.tmp
	rm -rf test
	rm -f el_CY.aff
	rm -f el_CY.dic
	rm -f sorted_worldlist*
el_CY_words.v3.dic:
	python3 list_words.py 
	#iconv -f UTF-8 -t ISO-8859-7//TRANSLIT -c el_CY_words.tmp > el_CY_words_iso.tmp
el_GR_utf8_words.tmp:
	iconv -f ISO-8859-7 -t UTF-8 el_GR/el_GR.dic > el_GR_utf8_words.tmp
sorted_worldlist.tmp: el_CY_words.v3.dic
	tail -n +2 el_GR_utf8_words.tmp> worldlist.tmp
	#tail -n +2  el_CY_words.v3.dic>> worldlist.tmp
	cat  magic_words.dic>> worldlist.tmp
	cat  place_words.dic>> worldlist.tmp
	cat  spyros_list.dic >> worldlist.tmp
	mv worldlist.tmp sorted_worldlist.tmp
	#sort worldlist.tmp >sorted_worldlist.tmp
sorted_worldlist_CY_only.tmp: el_CY_words.v3.dic
	#tail -n +2 el_GR_utf8_words.tmp> worldlist_CY_only.tmp
	#tail -n +2  el_CY_words.v3.dic>> worldlist_CY_only.tmp
	cat  magic_words.dic>> worldlist_CY_only.tmp
	cat  place_words.dic>> worldlist_CY_only.tmp
	cat  spyros_list.dic >> worldlist_CY_only.tmp
	#mv worldlist_CY_only.tmp sorted_worldlist_CY_only.tmp
	sort  -V worldlist_CY_only.tmp >sorted_worldlist_CY_only.tmp
el_CY.dic: sorted_worldlist.tmp
	echo "Running affixcompress.. this make take a few minutes"
	affixcompress sorted_worldlist.tmp 4 2> /dev/null
	echo "..complete"
	cat el_CY.aff_prefix > el_CY.aff
	cat sorted_worldlist.tmp.aff >> el_CY.aff
	mv sorted_worldlist.tmp.dic  el_CY.dic
el_CY_only.dic: sorted_worldlist_CY_only.tmp
	echo "Running affixcompress.. this make take a few minutes"
	affixcompress sorted_worldlist_CY_only.tmp 4 2> /dev/null
	echo "..complete"
	cat el_CY.aff_prefix > el_CY_only.aff
	cat sorted_worldlist_CY_only.tmp.aff >> el_CY_only.aff
	mv sorted_worldlist_CY_only.tmp.dic  el_CY_only.dic
install: el_CY.dic el_CY.aff
	cp el_CY.dic ~/Library/Spelling
	cp el_CY.aff ~/Library/Spelling
	cp el_CY.dic ../dict/
	cp el_CY.aff ../dict/
build: 

test: el_CY.dic el_CY.aff
	hunspell  -d el_CY -l corpus/test_1.txt > test_1.result.tmp
	diff test_1.result.tmp corpus/test_1.expected
#Αμμοχωστιανούς