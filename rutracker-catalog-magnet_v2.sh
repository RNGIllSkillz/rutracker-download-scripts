#!/usr/bin/env bash
export LC_ALL=C

# rutracker-catalog-magnet
# Create list with magnet url's from custom category ID
# Usage : sh rutracker-catalog-magnet.sh <ID_CATEGORY>
#
# Copyright (c) 2018 Denis Guriyanov <denisguriyanov@gmail.com>


# Variables
################################################################################
TR_URL='https://rutracker.org/forum'
TR_CATEGORY="$1"

DIR_DWN="$HOME/Downloads/Torrents"
DIR_TMP='/tmp/rds'
DIR_TMP_CAT="$DIR_TMP/category_$TR_CATEGORY"

SC_UA='Mozilla/5.0 (Macintosh; Intel Mac OS X 10.11; rv:44.0) Gecko/20100101 Firefox/44.0'


# BEGIN
################################################################################
if [ -z $TR_CATEGORY ]; then
  echo 'Please, enter category ID.'
  echo 'Example: rutracker-catalog-magnet.sh <ID_CATEGORY>'
  exit
fi

echo "Let's Go!\n"


# Check and create directories
################################################################################
if [ ! -d $DIR_TMP ]; then
  mkdir "$DIR_TMP"
fi
if [ ! -d $DIR_TMP_CAT ]; then
  mkdir -p "$DIR_TMP_CAT"
else
  # remove old files
  rm -rf "$DIR_TMP_CAT"/*
fi

if [ ! -d $DIR_DWN ]; then
  mkdir "$DIR_DWN"
fi


# Total pages
################################################################################
echo 'Get total pages in category...'

category_page=$(curl "$TR_URL/viewforum.php?f=$TR_CATEGORY&start=0" \
  -A "$SC_UA" \
  --show-error \
  -L \
  -s
)

# find latest pager link
# <a class="pg" href="viewforum.php?f=###&amp;start=###">###</a>&nbsp;&nbsp;
total_pages=$(echo $category_page \
  | sed -En 's/.*<a class=\"pg\" href=\".*\">([0-9]*)<\/a>&nbsp;&nbsp;.*/\1/p' \
  | head -1
)

echo "...complete!\n"

sleep 1


# Category Page
################################################################################
echo 'Download category pages...'

for page in $(seq 1 $total_pages); do
  page_link=$((page * 50 - 50)) # 50 items per page, ex. 0..50..100
  category_pages=$(curl "$TR_URL/viewforum.php?f=$TR_CATEGORY&start=$page_link" \
    -A "$SC_UA" \
    --show-error \
    -L \
    -s
  )
  echo "$category_pages" > "$DIR_TMP_CAT/category_page_$page.html"
  printf "\rProgress : %d of $total_pages" $page
done

echo "\n...complete!\n"

sleep 1


# Torrent ID
################################################################################
echo "Get torrent IDs..."

id_list="$DIR_TMP_CAT/ids_list.txt"
touch "$id_list"

for page in $(seq 1 $total_pages); do
  category_page="$DIR_TMP_CAT/category_page_$page.html"
  # find torrent topic link
  # <a id="tt-###" href="viewtopic.php?t=###">
  ids=$(cat $category_page \
    | sed -En 's/.*<a.*href=\"viewtopic\.php\?t=([0-9]*)\".*>.*/\1/p'
  )
  echo "$ids" >> "$id_list"
done

echo "...complete!\n"

sleep 1


# Magnet URL
################################################################################
echo 'Get magnet URLs...'
i=1
total_ids=$(cat "$id_list" | wc -l | sed 's/ //g')
magnet_list="$DIR_DWN/$TR_CATEGORY.txt"
shared_value_file="$DIR_DWN/shared_value.txt"

echo "$i" > "$shared_value_file"
# Check if the output file exists and remove it if it does
if [ -f "$magnet_list" ]; then
  rm -f "$magnet_list"
else
  touch "$magnet_list"
fi


# Define a function to extract magnet links
extract_magnet_link() {
  id="$1"
  TR_URL="$2"
  magnet_list="$3"
  total_ids="$4"
  shared_value_file="$5"
  
  torrent_page=$(curl "$TR_URL/viewtopic.php?t=$id" -A "$SC_UA" --show-error -L -s)
  magnet_link=$(echo "$torrent_page" | sed -En 's/.*<a.*href=\"(magnet:[^"]*)\".*>.*/\1/p')
  if [ "$magnet_link" ]; then
    echo "$magnet_link" >> "$magnet_list"    
  fi  
  # Read the shared value from the file
i=$(cat "$shared_value_file")

# Check if i is not empty and is a number
if [[ -n "$i" && "$i" =~ ^[0-9]+$ ]]; then
  i=$((i+1))

  # Write the updated shared value back to the file
  echo "$i" > "$shared_value_file"
else
  # Handle the case where i is not a number or is empty
  echo "Error: Invalid or missing value for i in the shared value file" >&2
fi

  echo "Progress : $i of $total_ids"
}

export -f extract_magnet_link
export TR_URL="$TR_URL"
export magnet_list="$magnet_list"
export total_ids="$total_ids"
export shared_value_file="$shared_value_file"

# Use xargs to parallelize the magnet link extraction
cat "$id_list" | xargs -n 1 -P 10 -I {} bash -c 'extract_magnet_link "{}" "$TR_URL" "$magnet_list" "$total_ids" "$shared_value_file"'

echo -e "\n...complete!\n"


# FINISH
################################################################################
total_links=$(cat $magnet_list \
  | wc -l \
  | sed 's/ //g'
)

echo "Total URLs : $total_links\n"
echo 'Enjoy...'

exit
