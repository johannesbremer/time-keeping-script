#import "@preview/letter-pro:2.1.0": letter-simple
#import "variables.typ" as variables

#set text(lang: "de")

#show: letter-simple.with(
  sender: (
    name: "MVZ Dissen",
    address: "Westendarpstr. 21-23, 49201 Dissen a.T.W.",
    extra: [
      #link("tel:+4954217556")[05421 / 755 (6)]\
      #link("mailto:service@mvzdissen.de")[service\@mvzdissen.de]\
    ],
  ),
  
  date: [#datetime.today().display("[day].[month].[year]")],
  subject: "Lohnstundenabrechnung",
)
Frau #variables.name hat in dem angegeben Zeitraum #variables.duration gearbeitet. Der Stundenlohn beträgt #variables.wage\0€. Mit der Lohnabrechnung werden #variables.pay überwiesen.

#let t = csv("table.csv")
#table(
  align: center,
  columns: (1fr, 1fr, 1fr, 2fr, 1fr),
  [*Datum*], [*Beginn*], [*Ende*], [*Dauer*], [*Lohn*],
   ..for (.., Datum, Beginn, Ende, Dauer, Lohn) in t {
    (Datum, Beginn, Ende, Dauer, Lohn)
  }
)

#v(1cm)
Dieses Dokument wurde automatisch generiert.