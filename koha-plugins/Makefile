.PHONY: all
all : koha-plugin-cwmars.kpz koha-plugin-sip2patron.kpz koha-plugin-html2marc.kpz

koha-plugin-cwmars.kpz: Koha/Plugin/Com/Bloovis/Cwmars.pm
	zip -r $@ $<

koha-plugin-sip2patron.kpz: Koha/Plugin/Com/Bloovis/Sip2patron.pm
	zip -r $@ $<

koha-plugin-html2marc.kpz: Koha/Plugin/Com/Bloovis/Html2marc.pm
	zip -r $@ $<

.PHONY: clean
clean:
	rm koha-plugin-cwmars.kpz koha-plugin-sip2patron.kpz koha-plugin-html2marc.kpz
