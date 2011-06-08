SRC=\
		src/main.opa\
		src/min_chat.opa\
		src/wiki_css.opa

all: opa_wiki.exe

opa_wiki.exe: $(SRC)
	opa -o $@ $^

clean:
	\rm -Rf *.exe _build _tracks *.log
