; Shared 24x36 cartoon refrigerator artwork, in painter's order.
; Each record is x, y, width, height, color. System white/silver/ice-blue and
; opaque black keep the chrome consistent in all five desktop themes.
fridge_art {
    const ubyte RECORD_SIZE = 5
    ubyte[] rectangles = [
        4,2,16,1,16, 3,3,18,29,16, 2,5,1,25,16, 21,5,1,25,16,
        4,4,16,26,15, 5,4,13,25,1, 18,5,2,24,12,
        5,5,12,9,14, 6,5,10,7,1,
        4,14,16,2,16,
        5,17,12,12,14, 6,17,10,10,1,
        5,32,4,2,16, 16,32,4,2,16,
        4,18,3,7,16, 4,18,2,6,15, 4,18,1,5,1,
        4,7,2,4,12, 4,7,1,3,1,
        9,8,2,3,16, 14,8,2,3,16,
        9,8,1,1,1, 14,8,1,1,1,
        11,12,3,1,16, 10,11,1,1,16, 14,11,1,1,16,
        8,18,1,4,1, 9,18,1,2,1,
        18,1,1,7,1, 15,4,7,1,1,
        22,23,1,5,1, 20,25,4,1,1
    ]
}
