\name{kb_adl_text}
\alias{kb_adl_text}
\title{Retrieve the TEI source of an ADL text}
\description{
Retrieve a volume or a single TEI element from the Royal Danish Library's
public Arkiv for Dansk Litteratur source repository.
}
\usage{
kb_adl_text(document, id = NULL, format = c("xml", "text"))
}
\arguments{
  \item{document}{An ADL XML filename such as \code{"hcaeventyr01val.xml"},
  or its source path starting with \code{"texts/"} or \code{"adl/texts/"}.}
  \item{id}{An optional TEI \code{xml:id} identifying an element.}
  \item{format}{Parsed TEI XML or the text content of the element.}
}
\value{
An \code{xml_document} for a complete TEI volume or an \code{xml_node}
when an ID is supplied. With \code{format = "text"}, return one character
string from the identified element or the volume's \code{<text>} element.
}
\examples{
\dontrun{
kb_adl_text("hcaeventyr01val.xml", "workid58084", format = "text")
}
}
