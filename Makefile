#GZIP=gzip -9 -k -f
GZIP=zopfli -i1000
MINCSS=cleancss
MINJS=compiler.jar
MINLUA=luasrcdiet --quiet --maximum --noopt-numbers -o
#LUAC=luac5.1 -o
LUAC=luac.cross -o

default: www/edit.min.htm.gz httpd.lc

www/script.min.js: www/edit.htm
	@awk 'BEGIN{js=0}/^<\/script>/{js=0}{if(js==1)print}/^<script>/{js=1}' "$<" | $(MINJS) > "$@"

www/style.min.css: www/edit.htm
	@awk 'BEGIN{css=0}/^<\/style>/{css=0}{if(css==1)print}/^<style.*>/{css=1}' "$<" | $(MINCSS) > "$@"

www/edit.min.htm: www/edit.htm www/style.min.css www/script.min.js
	@awk 'BEGIN{css=0;js=0}/^<\/style>/{css=0}/^<\/script>/{js=0}{if(css+js==0)print}/^<style.*>/{css=1;while(getline<"www/style.min.css")print}/^<script>/{js=1;while(getline<"www/script.min.js")print}' "$<" > "$@"

%.gz: %
	@$(GZIP) "$<"

%.lc: %.lua
	@$(LUAC) "$@" "$<"

%.min.lua: %.lua
	@$(MINLUA) "$@" "$<"

%.inc: %
        @od -An -vtu1 -w60 "$<" | sed -e "s/^ */_(\"\\\/" -e "s/ *$$/\")/" -e "s/ \+/\\\/g" -e "1 i file.open('$<','w')_=file.write" -e "$$ a file.close()_=nil" > "$@"
        @echo -n "Max line length: ";wc -L "$@"
        @echo -n "Lines: "; wc -l "$@"
        @echo -n "Size: ";wc -c "$@"

clean:
	@rm -f www/*.min.* www/*.gz www/*.inc *.min.* *.gz *.lc *.inc
