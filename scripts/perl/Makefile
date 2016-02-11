

# assumes sorted fragment file

OUT = 
READFILE = 
FRAGFILE = 

pipe:
	cat $(READFILE) | \
	grep -v -P '^@' | \
	perl -lane 'BEGIN{open(OUT,">$(OUT)___unmapped.tab")} $$F[2] eq "*" ? print OUT "-\t-\t+\t$$F[0]\t-" : print $$_; END{close(OUT)}' | \
	perl -lane 'print $$F[2],"\t",$$F[1]&0x10?($$F[3],"\t+"):($$F[3]+length($$F[9]-1),"\t-"),"\t",$$F[0]' | \
	sort -k 1,1 -k 2,2n | \
	python assign_fragment.py -frags $(FRAGFILE) -reads - -out $(OUT) ; \




