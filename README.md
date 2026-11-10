# kbdata

`kbdata` er en R-pakke til Det Kgl. Biblioteks luftfotos, digitale samlinger og tekstsamlinger. Søgninger returnerer som udgangspunkt et `data.frame`. De viste kald til KB’s offentlige endepunkter kræver ingen API-nøgle.

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

## Luftfotos omkring Viby på Fyn

```r
fotos <- kb_dsfl_search(
  bbox = c(xmin = 10.65, ymin = 55.47, xmax = 10.70, ymax = 55.52),
  type = "vertical",
  page_size = 20
)
head(fotos[c("title", "date", "longitude", "latitude")])
```

`bbox` bruger længde- og breddegrader i WGS 84. Rækkefølgen for en vektor uden navne er vest, syd, øst, nord. Tabellen hentes via KML og kan filtreres på dato, fototype og søgetekst. Brug `format = "json"` til GeoJSON-punkter fra REST-endepunktet med geografisk afgrænsning og paginering. `"rss"`, `"kml"` og `"mods"` giver XML.

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

## Paginering

Søgninger henter én side som standard. Brug `page` til at vælge startsiden, `page_size` til sidestørrelsen og `max_pages` til at hente flere sider. `max_pages = Inf` gennemgår hele resultatsættet fra den valgte startside. `attr(x, "kb_total")` angiver antal træffere, og `attr(x, "kb_pages_fetched")` angiver antal hentede sider.

Rå søgeformater giver en liste med ét element per hentet side. Eksempelvis er `kb_cop_search(edition, format = "mods")[[1L]]` en XML-repræsentation af første side. HTTP-timeout kan justeres med `options(kbdata.timeout = 60)`.

## API-specifikation

[OpenAPI 3.1-specifikationen](inst/openapi.yaml) er udarbejdet til pakken. Den dækker de offentlige endepunkter i KB’s [Swagger 2.0-fil](https://api.kb.dk/data/rest/swagger.json), de afprøvede svarformater, XML-feeds og Tekstportalens JSON. Den installerede fil kan findes med `system.file("openapi.yaml", package = "kbdata")`.

Licensen for selve R-koden er MIT. KB beskriver vilkårene for metadata og digitaliseret indhold i [sin API-dokumentation](https://github.com/kb-dk/access-digital-objects#licences--legalese).
