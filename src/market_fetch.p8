%import market_data
%import network_driver
%import floats
%import strings

; -----------------------------------------------------------------------------
; Market Watch network worker
; -----------------------------------------------------------------------------
;
; Kept in its own bank because TLS is performed by ZiModem, but the UART,
; command framing, response parsing, and buffers still take meaningful space.

market_fetch {
    const ubyte NO_VALUE = 255

    ubyte[6] symbol
    ubyte[49] api_key
    ubyte[161] fetch_command
    ubyte[12] price
    ubyte[12] previous_price
    ubyte[11] change

    sub append(str source, ubyte output) -> ubyte {
        ubyte index = 0
        while source[index] != 0 and output < 159 {
            fetch_command[output] = source[index]
            output++
            index++
        }
        return output
    }

    sub build_fetch_command(ubyte stock) {
        ubyte output = 0

        market_data.copy_symbol(stock, symbol)
        if market_data.is_public_asset(stock) {
            ; Official keyless current-price feed. It covers the three compact
            ; built-ins and asks clients to cache each result for 30 seconds.
            output = append(iso:"AT&G\"https://api.gold-api.com/price/", output)
            output = append(symbol, output)
        } else {
            market_data.copy_api_key(api_key)
            output = append(iso:"AT&G\"https://finnhub.io/api/v1/quote?symbol=", output)
            output = append(symbol, output)
            output = append(iso:"&token=", output)
            output = append(api_key, output)
        }
        fetch_command[output] = '"'
        output++
        fetch_command[output] = 0
    }

    sub find_json_value(str name) -> ubyte {
        ubyte name_length = strings.length(name)
        ubyte start = 0
        ubyte letter
        bool matches

        while start + name_length < network_driver.response_length {
            matches = true
            for letter in 0 to name_length - 1 {
                if network_driver.response[start + letter] != name[letter]
                    matches = false
            }
            if matches
                return start + name_length
            start++
        }
        return NO_VALUE
    }

    sub copy_json_number(str name, str destination, ubyte maximum,
                         bool percentage) -> bool {
        ubyte source = find_json_value(name)
        ubyte output = 0
        ubyte decimal_digits = 0
        bool decimal_seen = false

        if source == NO_VALUE
            return false
        if percentage and network_driver.response[source] != '-' {
            destination[output] = '+'
            output++
        }
        while source < network_driver.response_length and output < maximum {
            ubyte character = network_driver.response[source]
            if character == ',' or character == '}' or character == $0d
                break
            ; Market Watch intentionally presents clean whole-dollar prices.
            ; Percentage movement keeps two useful fractional digits instead
            ; of running a raw API number into the next column.
            if character == '.' {
                if not percentage
                    break
                decimal_seen = true
            } else if percentage and decimal_seen {
                if decimal_digits == 2
                    break
                decimal_digits++
            }
            destination[output] = character
            output++
            source++
        }
        if percentage and output < maximum {
            destination[output] = '%'
            output++
        }
        destination[output] = 0
        return output > 0
    }

    sub format_percentage(str source, str destination) {
        ubyte input = 0
        ubyte output = 0
        ubyte decimal_digits = 0
        bool decimal_seen = false

        if source[0] != '-' {
            destination[output] = '+'
            output++
        }
        while source[input] != 0 and output < 9 {
            ubyte character = source[input]
            if character == '.' {
                decimal_seen = true
            } else if decimal_seen {
                if decimal_digits == 2
                    break
                decimal_digits++
            }
            destination[output] = character
            output++
            input++
        }
        destination[output] = '%'
        destination[output + 1] = 0
    }

    sub calculate_public_move() {
        float old_value = floats.parse(previous_price)
        float new_value = floats.parse(price)

        if old_value == 0.0 {
            void strings.copy(iso:"0.00%", change)
            return
        }
        float movement = (new_value - old_value) * 100.0 / old_value
        format_percentage(floats.tostr(movement), change)
    }

    sub refresh() {
        ubyte stock = market_data.requested_stock()
        ubyte index
        bool received
        bool had_previous = false

        if market_data.is_public_asset(stock) {
            market_data.copy_price(stock, previous_price)
            if previous_price[0] >= '0' and previous_price[0] <= '9'
                had_previous = true
        }

        if not market_data.is_public_asset(stock) and
           not market_data.has_api_key() {
            market_data.set_error(stock)
            return
        }
        if not network_driver.modem_present and
           not network_driver.detect_modem() {
            market_data.set_error(stock)
            return
        }

        ; Disable command echo so the URL and private key never enter the
        ; response cache. This setting is not written to modem flash.
        void network_driver.send_command(iso:"ATE0", 180)
        build_fetch_command(stock)
        received = network_driver.send_command(fetch_command, 900)

        if market_data.is_public_asset(stock) {
            if received and
               copy_json_number(iso:"\"price\":", price, 11, false) {
                if had_previous
                    calculate_public_move()
                else
                    void strings.copy(iso:"0.00%", change)
                market_data.set_quote(stock, price, change)
            }
            else
                market_data.set_error(stock)
        } else {
            if received and
               copy_json_number(iso:"\"c\":", price, 11, false) and
               copy_json_number(iso:"\"dp\":", change, 9, true)
                market_data.set_quote(stock, price, change)
            else
                market_data.set_error(stock)
        }

        ; Do not leave the API key or complete request in ordinary RAM.
        for index in 0 to 48
            api_key[index] = 0
        for index in 0 to 160
            fetch_command[index] = 0
    }

    ; Refresh a dashboard-sized group in this roomy worker bank. Keeping the
    ; loop here saves precious bytes in the 8 KB Market Watch interface bank.
    sub refresh_group() {
        ubyte stock = market_data.requested_stock()
        ubyte stop = stock + 3

        if stop > market_data.count()
            stop = market_data.count()
        while stock < stop {
            market_data.set_requested_stock(stock)
            refresh()
            stock++
        }
    }
}
