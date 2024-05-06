const stundenlohn = 12.5
const lohnabrechnungstag = 16 # Stichtag z.B. immer der 16. im Monat.

let namescsv = open names.csv
let names = $namescsv | select username

let input = open input.xlsx
    | get Sheet
    | headers
    | rename user-id name place date device-id
    | select name date
    | update date { |item| $item.date | into datetime }
    | insert day { |row| $row.date | format date "%d" | into int }

splitupmonths $input

def splitupmonths [inputlist] {
    let firstdate = $inputlist | first

    if (( $firstdate | get day ) < $lohnabrechnungstag ) {
        let date = $firstdate | get date
        table2pdf $date $inputlist
    } else {
        let dateint = $firstdate
            | get date
            | into int

        let nextmonth = $dateint + 2_628_000_000_000_000 # 2,628,000,000,000,000ns in an average month
            | into datetime

        table2pdf $nextmonth $inputlist
    }
}

def table2pdf [date: datetime, inputlist: list] {
    let firstpart = $date
        | format date "%Y-%m-"

    let cutoffdate = [$firstpart, $lohnabrechnungstag] 
        | str join
        | into datetime

    let thismonth = $inputlist
        | where date < $cutoffdate

    for $namerow in $names {
        let name = $namerow | values | first
        let allClicksByName = $thismonth
            | where name == $name
            | reject name

        if ( $allClicksByName | is-empty ) {} else {

            let days = $thismonth
                | where name == $name
                | uniq-by day
                | sort-by day

            let start2end = $days
                | insert start { |row| $allClicksByName | where day == $row.day | get date | first }
                | insert end { |row| $allClicksByName | where day == $row.day  | get date | last }
                | insert duration { |row| ( $row.end | into int ) - ( $row.start | into int ) | into duration }
                | insert pay { |row| (( $row.duration | into int ) / 3_600_000_000_000 ) * $stundenlohn 
                                    | math round --precision 2 
                                    | into string
                                    | str replace '.' ',' }
                | update day { |row| $row.start | format date "%d.%m.%Y" }
                | update start { || format date "%H:%M Uhr" }
                | update end { || format date "%H:%M Uhr" }
                | update pay { |row| [$row.pay, '€'] | str join }
                | reject name date

            let totalduration = $start2end 
                | get duration 
                | math sum

            let totalpay = (( $totalduration | into int ) / 3_600_000_000_000 ) * $stundenlohn # 3,600,000,000,000ns in a hour
                | math round --precision 2 
                | into string 
                | str replace '.' ','

            ['#let pay = "',$totalpay, '€";'] 
                | str join
                | save --append variables.typ

            let totaldurationstr = $totalduration
                | into string
                | str replace 'day' ' Tag,' 
                | str replace 'hr' ' Stunden,' 
                | str replace 'min' ' Minuten'

            ['#let duration = "',$totaldurationstr, '";'] 
                | str join
                | save --append variables.typ

            let fullname = $namescsv | where username == $name | get official-name | first

            ['#let name = "',$fullname, '";'] 
                | str join
                | save --append variables.typ

            let wage = $stundenlohn | into string | str replace '.' ','
            
            ['#let wage = "',$wage, '";'] 
                | str join
                | save --append variables.typ

            $start2end
                | update duration { |row| $row.duration 
                                        | into string 
                                        | str replace 'hr' ' Stunden' 
                                        | str replace 'min' ' Minuten' 
                                        | str replace 'sec' ' Minuten' } # it's only ever 0 seconds
                | to csv --noheaders
                | save table.csv

            let filenamedate = $cutoffdate | format date "%Y-%m"
            let filename = [$name, $filenamedate, '.pdf'] | str join
            typst compile letter.typ $filename
            rm table.csv variables.typ
        }
    }

    let nextinputlist = $inputlist | where date > $cutoffdate

    if ( $nextinputlist | is-empty) {} else {
        splitupmonths $nextinputlist
    }
}