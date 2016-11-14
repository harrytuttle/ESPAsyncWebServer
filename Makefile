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
	@$(GZIP) -i1000 "$<"

%.lc: %.lua
	@$(LUAC) "$@" "$<"

%.min.lua: %.lua
	@$(MINLUA) "$@" "$<"

%.inc: %
	@awk 'BEGIN{i=0;RS="";print "file.open(\"$<\",\"w\")_=file.write\n"}\
{while (i<=length($$0)) print "_([==[",substr($$0,i+=255,255),"]==])"}\
END{print "file.close()_=nil"}' "$<" > "$@"

clean:
	@rm -f www/*.min.* www/*.gz www/*.inc *.min.* *.gz *.lc *.inc
