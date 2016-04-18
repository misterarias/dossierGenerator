#!/bin/bash
TOPDIR=$(cd $(dirname $0) ; pwd);

[ $# -ne 1 ] && \
  echo "Missing parameter: images folder." && \
  exit 2

TEMPLATE_FILE="$TOPDIR/templates/section.tmpl"
IMAGE_FOLDER=$(cd "$1" ; pwd)
MAIN_FILE="${TOPDIR}/section.html"

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
}

insert_description() {
  local description_file=$1
  local index_file=$2
  
  descripcion="$(cat "$description_file")"
  escaped_description="$(echo "${descripcion}" | sed ':a;N;$!ba;s/\n/<br \/>/g' | sed 's/\$/\\$/g')"
  sub "#DESCRIPTION" "${escaped_description}" "$index_file"
}


> "$MAIN_FILE"

find "$IMAGE_FOLDER"  -type d  -print0 | while IFS= read -r -d '' dir ; do
  if [ "$dir" = "$IMAGE_FOLDER" ] ; then
    continue
  fi

  title=$(basename "$dir")
  invalid_folder=0
  index_file="$(mktemp /tmp/.index.html.XXXXX)"
  cat "$TEMPLATE_FILE" > "$index_file"

  find "$dir" -type f  -print0 | while IFS= read -r -d '' file ; do
    echo "$file" | grep -qi "~" && continue

    file_info=$(file "$file")
    echo "$file_info" | grep -qi image && insert_image "$file" "$index_file" && continue
    echo "$file_info" | grep -qi text && insert_description "$file" "$index_file" && continue
    
    # Ooops, shouldn't be here
    echo "Folder contains no valid data: $file" && invalid_folder=1
  done

  if [ $invalid_folder -eq 1 ] ; then
    echo "Folder contains no valid data: $dir"
  else 
    sub "#TITLE" "${title}" "$index_file"
    
    cat "$index_file"  >> "$MAIN_FILE"
    rm -f "$index_file"
  fi
done

# Create FINAL file
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
