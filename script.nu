const $stundenlohn = 12.5

let input = open input.xlsx
    | get Sheet
    | headers
    | rename user-id name place date device-id
    | select name date
    | update date { |item| $item.date | into datetime | format date }
    | insert day { |row| $row.date | format date "%d" | into int }

let namescsv = open names.csv
let names = $namescsv | select username

for $namerow in $names {

    let name = $namerow | values | first

    let allClicksByName = $input
        | where name == $name
        | reject name

    if ( $allClicksByName | is-empty ) {} else {

        let days = $input
            | where name == $name
            | uniq-by day
            | sort-by day

        let start2end = $days
            | insert start { |row| $allClicksByName | where day == $row.day | get date | first | into datetime }
            | insert end { |row| $allClicksByName | where day == $row.day  | get date | last | into datetime }
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

        let totalduration = $totalduration
            | into string
            | str replace 'day' ' Tag,' 
            | str replace 'hr' ' Stunden,' 
            | str replace 'min' ' Minuten'

        ['#let duration = "',$totalduration, '";'] 
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
        
        let filename = [$name, '.pdf'] | str join
        typst compile letter.typ $filename
        rm table.csv variables.typ
    }
}