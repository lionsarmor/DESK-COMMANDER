; -----------------------------------------------------------------------------
; Shared Market Watch cache
; -----------------------------------------------------------------------------
;
; Banked applications cannot safely point at one another's variables. This
; small database therefore lives in VERA RAM at state_data.MARKET ($1:6500), where both the
; desktop and the loadable Market Watch app can reach it. The state service
; mirrors this region to device 8 so the watchlist and last quotes survive.

%import state_data

market_data {
    const ubyte VRAM_BANK = 1
    const uword BASE = state_data.MARKET
    const ubyte MAX_STOCKS = 12
    const ubyte RECORD_SIZE = 32
    const uword RECORDS = BASE + 16
    const uword API_KEY = BASE + 416
    const ubyte API_KEY_SIZE = 49

    const ubyte STATE_PENDING = 0
    const ubyte STATE_FRESH = 1
    const ubyte STATE_ERROR = 2

    sub read(uword address) -> ubyte {
        return cx16.vpeek(VRAM_BANK, address)
    }

    sub write(uword address, ubyte value) {
        cx16.vpoke(VRAM_BANK, address, value)
    }

    sub record_address(ubyte index) -> uword {
        return RECORDS + (index as uword) * RECORD_SIZE
    }

    sub initialize() {
        uword offset

        if read(BASE) == 'M' and read(BASE + 1) == 'R' and
           read(BASE + 2) == 'K' and read(BASE + 3) == 'T' {
            return
        }

        ; A new profile begins with three useful requested defaults.
        for offset in 0 to 479
            write(BASE + offset, 0)
        write(BASE, 'M')
        write(BASE + 1, 'R')
        write(BASE + 2, 'K')
        write(BASE + 3, 'T')
        copy_to(RECORDS, iso:"GOOG", 5)
        copy_to(RECORDS + RECORD_SIZE, iso:"MSFT", 5)
        copy_to(RECORDS + RECORD_SIZE * 2, iso:"TSLA", 5)
        for offset in 0 to 2 {
            copy_to(RECORDS + offset * RECORD_SIZE + 6, iso:"--", 11)
            copy_to(RECORDS + offset * RECORD_SIZE + 18, iso:"--", 10)
            write(RECORDS + offset * RECORD_SIZE + 29, STATE_PENDING)
        }
        write(BASE + 4, 3)
        state_data.save()
    }

    sub install_featured_assets() {
        ; add() safely stops at MAX_STOCKS, so a full personal watchlist wins
        ; over the suggested built-in assets.
        if not contains(iso:"XAU")
            void add(iso:"XAU")
        if not contains(iso:"XAG")
            void add(iso:"XAG")
        if not contains(iso:"BTC")
            void add(iso:"BTC")
    }

    sub count() -> ubyte {
        return read(BASE + 4)
    }

    sub current_page() -> ubyte {
        return read(BASE + 5)
    }

    sub set_requested_stock(ubyte index) {
        write(BASE + 6, index)
    }

    sub requested_stock() -> ubyte {
        return read(BASE + 6)
    }

    sub page_count() -> ubyte {
        ubyte stocks = count()
        if stocks == 0
            return 1
        return (stocks + 2) / 3
    }

    sub next_page() {
        ubyte page = current_page() + 1
        if page >= page_count()
            page = 0
        write(BASE + 5, page)
    }

    sub keep_page_valid() {
        if current_page() >= page_count()
            write(BASE + 5, 0)
    }

    sub copy_from(uword address, str destination, ubyte maximum) {
        ubyte index = 0
        ubyte value = read(address)

        while value != 0 and index < maximum {
            destination[index] = value
            index++
            value = read(address + index)
        }
        destination[index] = 0
    }

    sub copy_symbol(ubyte index, str destination) {
        copy_from(record_address(index), destination, 5)
    }

    sub is_public_asset(ubyte index) -> bool {
        ; XAU (gold), XAG (silver), and BTC use Gold API's keyless endpoint.
        ; Compare stored ISO/ASCII bytes directly; no temporary string needed.
        uword address = record_address(index)
        if read(address) == $58 and read(address + 1) == $41 and
           (read(address + 2) == $55 or read(address + 2) == $47) and
           read(address + 3) == 0
            return true
        if read(address) == $42 and read(address + 1) == $54 and
           read(address + 2) == $43 and read(address + 3) == 0
            return true
        return false
    }

    sub copy_price(ubyte index, str destination) {
        copy_from(record_address(index) + 6, destination, 11)
    }

    sub copy_change(ubyte index, str destination) {
        copy_from(record_address(index) + 18, destination, 10)
    }

    sub state(ubyte index) -> ubyte {
        return read(record_address(index) + 29)
    }

    sub copy_to(uword address, str source, ubyte maximum) {
        ubyte index = 0

        while source[index] != 0 and index < maximum {
            write(address + index, source[index])
            index++
        }
        write(address + index, 0)
    }

    sub add(str symbol) -> bool {
        ubyte stocks = count()
        uword address

        if stocks >= MAX_STOCKS
            return false
        address = record_address(stocks)
        copy_to(address, symbol, 5)
        copy_to(address + 6, iso:"--", 11)
        copy_to(address + 18, iso:"--", 10)
        write(address + 29, STATE_PENDING)
        write(BASE + 4, stocks + 1)
        state_data.save()
        return true
    }

    sub contains(str symbol) -> bool {
        ubyte stock
        ubyte letter
        bool same

        if count() == 0
            return false
        for stock in 0 to count() - 1 {
            same = true
            for letter in 0 to 5 {
                if read(record_address(stock) + letter) != symbol[letter]
                    same = false
                if symbol[letter] == 0
                    break
            }
            if same
                return true
        }
        return false
    }

    sub remove(ubyte index) {
        ubyte stocks = count()
        ubyte source
        ubyte byte_index

        if index >= stocks
            return
        source = index
        while source + 1 < stocks {
            for byte_index in 0 to RECORD_SIZE - 1
                write(record_address(source) + byte_index,
                      read(record_address(source + 1) + byte_index))
            source++
        }
        for byte_index in 0 to RECORD_SIZE - 1
            write(record_address(stocks - 1) + byte_index, 0)
        write(BASE + 4, stocks - 1)
        keep_page_valid()
        state_data.save()
    }

    sub set_quote(ubyte index, str price, str change) {
        uword address = record_address(index)
        copy_to(address + 6, price, 11)
        copy_to(address + 18, change, 10)
        write(address + 29, STATE_FRESH)
        state_data.save()
    }

    sub set_error(ubyte index) {
        uword address = record_address(index)
        ; Keep a valid cached price as the next comparison baseline. A brief
        ; network failure must not erase yesterday's/last session's history.
        if read(address + 6) < '0' or read(address + 6) > '9' {
            copy_to(address + 6, iso:"OFFLINE", 11)
            copy_to(address + 18, iso:"--", 10)
        }
        write(address + 29, STATE_ERROR)
        state_data.save()
    }

    sub has_api_key() -> bool {
        return read(API_KEY) != 0
    }

    sub copy_api_key(str destination) {
        copy_from(API_KEY, destination, API_KEY_SIZE - 1)
    }

    sub set_api_key(str source) {
        ubyte index
        for index in 0 to API_KEY_SIZE - 1
            write(API_KEY + index, 0)
        copy_to(API_KEY, source, API_KEY_SIZE - 1)
        state_data.save()
    }
}
