# kbdata

`kbdata` er en R-pakke til Det Kgl. Biblioteks luftfotos, digitale samlinger, tekstsamlinger og DR-arkiv. Søgninger returnerer som udgangspunkt et `data.frame`. De viste kald til KB’s offentlige endepunkter kræver ingen API-nøgle.

## Installation

```r
install.packages("remotes")
remotes::install_github("KUBDatalab/kbdata")
library(kbdata)
```

| Dataindgang | R-funktioner | Data du får |
| --- | --- | --- |
| Danmark set fra luften (DSfL) | `kb_dsfl_search()` | Luftfotos i et afgrænset område med koordinater og billedlinks |
| Digitale samlinger (COP) | `kb_cop_editions()`, `kb_cop_search()`, `kb_cop_navigation()`, `kb_cop_images()` | Samlings-ID'er, metadata, emnehierarkier og links til billeder og bogsider |
| Tekstsamlinger | `kb_text_search()`, `kb_text_get()`, `kb_adl_text()` | Metadata og indekseret tekst fra Tekstportalen samt TEI-kildetekster fra Arkiv for Dansk Litteratur |
| DR-arkivet | `kb_dr_search()`, `kb_dr_get()`, `kb_dr_facets()` | Metadata og arkivlinks til radio- og tv-udsendelser samt antal træffere pr. kanal, kategori og år |

## Luftfotos omkring Viby på Fyn

```r
fotos <- kb_dsfl_search(
  bbox = c(xmin = 10.65, ymin = 55.47, xmax = 10.70, ymax = 55.52),
  type = "vertical",
  page_size = 20
)
head(fotos[c("title", "date", "longitude", "latitude")])
```

`bbox` bruger længde- og breddegrader i WGS 84. Rækkefølgen for en vektor uden navne er vest, syd, øst, nord. Tabellen hentes via KML, kan filtreres på dato, fototype og søgetekst og omsætter ældre billedlinks til IIIF-adresser. Brug `format = "json"` til GeoJSON-punkter fra REST-endepunktet med geografisk afgrænsning og paginering. `"rss"`, `"kml"` og `"mods"` giver XML.

## Digitale samlinger og billeder

```r
samlinger <- kb_cop_editions()
samlinger[c("id", "title")]

billeder <- kb_cop_search(
  edition = "/images/billed/2010/okt/billeder/da/",
  query = "Kierkegaard",
  not_before = "1900-01-01",
  not_after = "1910-12-31",
  page_size = 10,
  max_pages = 2
)
head(billeder[c("title", "thumbnail_url")])

sider <- kb_cop_images("/manus/musman/2010/dec/viser/object23942/en/")
download.file(sider$thumbnail_url[[1L]], "visebog.jpg", mode = "wb")
```

Brug `format = "mods"` for at få de bibliografiske metadata i XML. `kb_cop_images()` læser billedlinks fra objektets MODS-post, herunder links til enkeltsider. `kb_cop_navigation()` returnerer emnehierarkiet omkring et emne-ID.

## Tekstsamlinger

```r
tekster <- kb_text_search(
  "Jerusalem",
  collection = "adl",
  author = "Munch-Petersen, Gustaf",
  category = "work"
)
head(tekster[c("title", "author", "id")])
vaerk <- kb_text_get(tekster$id[[1L]])

fyrtoejet <- kb_adl_text("hcaeventyr01val.xml", "workid58084", format = "text")
```

`text` indeholder indekseret tekst, hvor KB stiller den til rådighed. Brug `kb_adl_text()` med standardformatet `"xml"` for at arbejde med den fulde TEI-struktur.

Tekstsøgning bruger som standard Tekstportalens JSON-endepunkt. Vælger du `source = "portal"`, bruges det oprindelige tekstendepunkt på `api.kb.dk`, som gav HTTP 500 ved afprøvningen. Se [Tekstportalen](https://tekster.kb.dk/).

## DR-arkivet

```r
udsendelser <- kb_dr_search(
  '"Bamse og Kylling"',
  media = "tv",
  channel = "DR 1",
  not_before = "2006-01-01",
  not_after = "2010-12-31",
  page_size = 10
)
udsendelser[c("title", "channel", "broadcast_date", "duration_seconds", "url")]
post <- kb_dr_get(udsendelser$id[[1L]], format = "json")

fordeling <- kb_dr_facets('"P1 Debat"', media = "radio")
subset(fordeling, facet == "channel")
```

`kb_dr_search()` søger i arkivets metadata. Brug anførselstegn inde i søgestrengen til fraser og `*` eller `?` som jokertegn. Flere værdier i `channel` eller `genre` matches med OR inden for det enkelte filter. Brug værdierne fra `kb_dr_facets()` til at se arkivets kanal- og kategorinavne.

Datogrænserne er inklusive og følger dansk lokaltid. Tabellen har både lokal sendedato og tidsstempler i UTC. `kb_dr_get()` kan returnere en tabel med én udsendelse eller dens beskrivende JSON-LD-felter. Kolonnen `url` åbner posten hos KB, hvor udsendelsen kan afspilles efter KB’s vilkår. [KB’s vejledning til DR-arkivet](https://www.kb.dk/find-materiale/soegeindgange/dr-arkivet)

Pakken opretter automatisk den anonyme session, som arkivets webgrænseflade bruger. Endepunkterne er knyttet til webgrænsefladen og kan ændres.

## Paginering

Søgninger henter én side som standard. Brug `page` til at vælge startsiden, `page_size` til sidestørrelsen og `max_pages` til at hente flere sider. `max_pages = Inf` henter alle tilgængelige sider fra den valgte startside. `attr(x, "kb_total")` angiver antal træffere, og `attr(x, "kb_pages_fetched")` angiver antal hentede sider.

DR-arkivet accepterer en nulbaseret startposition på højst 2.000. `kb_dr_search()` giver en advarsel, hvis grænsen afskærer en ønsket side, og returnerer de hentede resultater. Afgræns søgningen med f.eks. dato, kanal eller kategori for at få et mindre resultatsæt.

Rå søgeformater giver en liste med ét element per hentet side. Eksempelvis er `kb_cop_search(edition, format = "mods")[[1L]]` en XML-repræsentation af første side. HTTP-timeout kan justeres med `options(kbdata.timeout = 60)`.

## API-specifikation

[OpenAPI 3.1-specifikationen](inst/openapi.yaml) er udarbejdet til pakken. Den dækker de offentlige endepunkter i KB’s Swagger 2.0-fil, XML-feeds, Tekstportalens JSON og DR-arkivets session, søgning og postopslag. Den installerede fil kan findes med `system.file("openapi.yaml", package = "kbdata")`. [KB’s Swagger-fil](https://api.kb.dk/data/rest/swagger.json)

Licensen for selve R-koden er MIT. KB beskriver vilkårene for metadata og digitaliseret indhold i [sin API-dokumentation](https://github.com/kb-dk/access-digital-objects#licences--legalese).
