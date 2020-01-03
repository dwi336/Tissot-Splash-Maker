#!/bin/bash
echo "------------------------------------------"
echo " Splash Image Maker"
echo
echo "Creating splash.img ........"
echo

function error_exit () {
    echo $1
    echo
    echo
    read -rsp $'Press any key to continue...\n' -n 1 key
    exit
}

rm "splash.img" 2>/dev/null 

InMaxSizesBytes=(100864 613888 101888 153088 204800)

input_img_filename="input/0x.png"

output="splash.img"

# Verify all PNGs exist and are of proper size
for((i=0; i<5; i++))
do
    filename=${input_img_filename//x/$((i+1))}
    echo "Verifying size of:" $filename
    if [ ! -f $filename ] || [ ! -s $filename ]
    then
        error_exit "File $filename is empty or does not exist"
    fi
done

# Write splash.img header
dd if=/dev/zero of="$output" bs=1024 count=1 2>/dev/null

# Convert images to RLE
for((i=0; i<5; i++))
do
    filename=${input_img_filename//x/$((i+1))}
    command="python2 png2rle.py $filename"
    echo $command
    $command

    if [ ! -f "output.rle" ] || [ ! -s "output.rle" ]
    then
        error_exit "RLE Conversion failed! - output.rle does not exist"
    else
        img_size=$(wc -c output.rle 2>/dev/null | awk '{print $1}')
        if (( $img_size> ${InMaxSizesBytes[i]} ))
        then
            error_exit "File too big!"
        else
            imgf="output.rle"

            img_sector_size=0
            for ((j = 1; j<=${InMaxSizesBytes[i]}-$img_size; j++))
            do
                if (( ($img_size + $j) % 512 == 0 )) && (( img_sector_size==0 ))
                then
                    img_sector_size=$(( ($img_size + $j) / 512 ))
                fi
            done

            headerf="splash_header.rle"

            BYTEONE=$(( $img_sector_size & 0xFF ))
            BYTETWO=$(( ($img_sector_size >> 8) & 0xFF ))
            BYTETHREE=$(( ($img_sector_size >> 16) & 0xFF ))
            BYTEFOUR=$(( ($img_sector_size >> 24) & 0xFF ))

            BYTEONE=$( printf "%x" $BYTEONE )
            BYTETWO=$( printf "%x" $BYTETWO )
            BYTETHREE=$( printf "%x" $BYTETHREE )
            BYTEFOUR=$( printf "%x" $BYTEFOUR )
            bytestring="\x$BYTEONE\x$BYTETWO\x$BYTETHREE\x$BYTEFOUR"
            printf "%b" $bytestring > "header.bin"

            paddingsize=$((512-20-4))
            dd if=/dev/zero of="header_padding.bin" bs=$paddingsize count=1 2>/dev/null

            cat $headerf "header.bin" "header_padding.bin" >> $output  2>/dev/null

            paddingsize=$((${InMaxSizesBytes[i]}-$img_size))
            dd if=/dev/zero of="content_padding.bin" bs=$paddingsize count=1 2>/dev/null
            cat $imgf "content_padding.bin" >> $output  2>/dev/null
        fi
    fi
done

rm "header.bin" 2>/dev/null 
rm "header_padding.bin" 2>/dev/null 
rm "output.rle" 2>/dev/null 
rm "content_padding.bin" 2>/dev/null

exit

