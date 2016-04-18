#!/bin/bash

sub() {
  local this=$1
  local by_this=$2
  local here=$3

  sed -i.bk -e "s|$this|$by_this|g" "$here"
}

insert_image() {
  local image=$1
  local index_file=$2

  image_base=$(basename "$image")
  image_index=$(echo $image_base | grep -o "^[1-6]")
  image_name=$(echo $image_base | sed -e 's#^[^a-zA-Z]*##g' -e 's/.jpg//g' -e 's/.JPG//g' )

  sub "#IMAGE${image_index}_SRC" "${image}" "$index_file"
  sub "#IMAGE${image_index}_TEXT" "${image_name}" "$index_file"

  if [ ! -z "$ADJUST_ORIENTATION" ] ; then
    # 6 means the image is rotated
    local orientation=$(identify -format '%[EXIF:Orientation]' "$image" )
    image_class='image-landscape'
    [ $orientation -eq 6 ] && image_class="image-left"
    sub "#IMAGE${image_index}_CLASS" "${image_class}" "$index_file"
  fi
}

insert_description() {
  local description_file=$1
  local index_file=$2
  
  descripcion="$(cat "$description_file")"
  escaped_description="$(echo "${descripcion}" | sed ':a;N;$!ba;s/\n/<br \/>/g' | sed 's/\$/\\$/g')"
  sub "#DESCRIPTION" "${escaped_description}" "$index_file"
}

process_dir() {
  local title=$(basename "$dir")
  local invalid_folder=0
  local index_file="$(mktemp /tmp/.index.html.XXXXX)"

  # copy the template into a new file
  cat "$TEMPLATE_FILE" > "$index_file"
  find "$dir" -maxdepth 1 -type f  -print0 | while IFS= read -r -d '' file ; do
    echo "$file" | grep -qi "~" && continue

    file_info=$(file "$file")
    echo "$file_info" | grep -qi "image data" && insert_image "$file" "$index_file" && continue
    echo "$file_info" | grep -qi "text" && insert_description "$file" "$index_file" && continue

    # Ooops, shouldn't be here
    echo "Folder '$dir' contains no valid data: $file" && return 
  done

  sub "#TITLE" "${title}" "$index_file"
  cat "$index_file"  >> "$MAIN_FILE"
  rm -f "$index_file"
}

process_image_folder() {
  #find "$IMAGE_FOLDER"  -type d -print0 | while IFS= read -r -d '' dir ; do
  local tmp_file=$(mktemp  /tmp/.tmpdirXXXX)
  IFS=$';'
  find "$IMAGE_FOLDER"  -type d | sort -h > "$tmp_file"
  unset IFS
  while read dir ; do
    [ $(find "$dir" -maxdepth 1 -type f | wc -l) -gt 0 ] && \
      process_dir "$dir"
  done < "$tmp_file"
  rm -rf "$tmp_file"
}

create_final_file() {
  FINAL_FILE="${TOPDIR}/index.html"
  START_TEMPLATE="$TOPDIR/templates/start.tmpl"
  END_TEMPLATE="$TOPDIR/templates/ending.tmpl"
  cat > "$FINAL_FILE" << EOF
  $(cat "$START_TEMPLATE")
  $(cat "$MAIN_FILE")
  $(cat "$END_TEMPLATE")
EOF

  # REMOVE temps
  rm -rf "$MAIN_FILE"
  echo "Done! Created: $FINAL_FILE"
}

# Check params
[ $# -ne 1 ] && \
  echo "Missing parameter: images folder." && \
  exit 2

[ -z $(which identify) -a ! -z "$ADJUST_ORIENTATION" ] &&
  echo "Missing command: 'identify'. Please install ImageMagick" && \
  exit 2

TOPDIR=$(cd $(dirname $0) ; pwd);
TEMPLATE_FILE="$TOPDIR/templates/section.tmpl"
IMAGE_FOLDER=$(cd "$1" ; pwd)
MAIN_FILE="${TOPDIR}/section.html"
> "$MAIN_FILE"

process_image_folder
create_final_file
