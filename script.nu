def main [
    table: string # The table that to be used as your input. Must end with ".xlsx".
    --day (-d) = 16 # The cut-off day for the monthly reports.
    --names (-n) = "names.csv" # A .csv file for the username and the full name respectively. The corresponding file must have two columns and the first line must be "username,full-name".
    --pay (-p) = 12.5 # The hourly wage to be used.
]: nothing -> nothing {    
    let namescsv = $names | open

    let input = $table
        | open
        | get Sheet
        | headers
        | rename user-id name place date device-id
        | select name date
        | update date { || into datetime }
        | insert day { |row| $row.date | format date "%d" | into int }

    splitupmonths $input $day $namescsv $pay
}

def splitupmonths [input: list, day: int, namescsv: list, pay: float]: nothing -> nothing {
    let firstdate = $input | first

    if (( $firstdate | get day ) < $day ) {
        let date = $firstdate | get date
        table2pdf $date $input $day $namescsv $pay
    } else {
        let dateint = $firstdate
            | get date
            | into int

        let nextmonth = $dateint + 2_628_000_000_000_000 # 2,628,000,000,000,000ns in an average month
            | into datetime

        table2pdf $nextmonth $input $day $namescsv $pay
    }
}

def table2pdf [date: datetime, input: list, day: int, namescsv: list, pay: float]: nothing -> nothing {
    let firstpart = $date
        | format date "%Y-%m-"

    let cutoffdate = [$firstpart, $day] 
        | str join
        | into datetime

    let thismonth = $input
        | where date < $cutoffdate
    
    let usernames = $namescsv | select username

    for $namerow in $usernames {
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
                | insert pay { |row| (( $row.duration | into int ) / 3_600_000_000_000 ) * $pay 
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

            let totalpay = (( $totalduration | into int ) / 3_600_000_000_000 ) * $pay # 3,600,000,000,000ns in an hour
                | math round --precision 2

            ['#let pay = "',$totalpay, '€";'] 
                | str join
                | str replace '.' ','
                | save --append variables.typ

            let totaldurationstr = $totalduration
                | into string
                | str replace 'day' ' Tag,' 
                | str replace 'hr' ' Stunden,' 
                | str replace 'min' ' Minuten'

            ['#let duration = "',$totaldurationstr, '";'] 
                | str join
                | save --append variables.typ

            let fullname = $namescsv | where username == $name | get full-name | first

            ['#let name = "',$fullname, '";'] 
                | str join
                | save --append variables.typ
            
            ['#let wage = "',$pay, '";'] 
                | str join
                | str replace '.' ','
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

    let nextinput = $input | where date > $cutoffdate

    if ( $nextinput | is-empty ) { return } else {
        splitupmonths $nextinput $day $namescsv $pay
    }
}