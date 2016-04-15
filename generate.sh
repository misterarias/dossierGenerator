#!/bin/bash
TOPDIR=$(cd $(dirname $0) ; pwd);

[ $# -ne 1 ] && \
  echo "Missing parameter: images folder." && \
  exit 2

TEMPLATE_FILE="$TOPDIR/templates/index.html.tmpl"
IMAGE_FOLDER=$(cd "$1" ; pwd)

sub() {
  local this=$1
  local by_this=$2
  local here=$3

  sed -i.bk -e "s|$this|$by_this|g" "$here"
}

insert_image() {
  local image=$1
  local index_file=$2

  image_src=$(basename "$image")
  image_index=$(echo $image_src | grep -o "^[1-6]")
  image_name=$(echo $image_src | sed -e 's#^[1-6]\s*##g' -e 's#\.[a-zA-Z]*$##g')

  sub "#IMAGE${image_index}_SRC" "${image_src}" "$index_file"
  sub "#IMAGE${image_index}_TEXT" "${image_name}" "$index_file"
}

insert_description() {
  local description_file=$1
  local index_file=$2
  
  descripcion="$(cat "$description_file")"
  escaped_description="$(echo "${descripcion}" | sed ':a;N;$!ba;s/\n/<br \/>/g' | sed 's/\$/\\$/g')"
  sub "#DESCRIPTION" "${escaped_description}" "$index_file"
  
}

find "$IMAGE_FOLDER"  -type d  -print0 | while IFS= read -r -d '' dir ; do
  if [ "$dir" = "$IMAGE_FOLDER" ] ; then
    continue
  fi

  # Cleanup old HTML
  find "$dir" -iname "*.html*" -delete

  title=$(basename "$dir")
  invalid_folder=0
  index_file="$(mktemp /tmp/.index.html.XXXXX)"
  cat "$TEMPLATE_FILE" > "$index_file"

  pushd "$dir" > /dev/null
  find . -type f  -print0 | while IFS= read -r -d '' file ; do
    file_info=$(file "$file")
    echo "$file_info" | grep -qi image && insert_image "$file" "$index_file" && continue
    echo "$file_info" | grep -qi text && insert_description "$file" "$index_file" && continue
    
    # Ooops, shouldn't be here
    echo "Folder contains no valid data" && invalid_folder=1
  done

  if [ $invalid_folder -eq 1 ] ; then
    echo "Folder contains no valid data"
  else 
    sub "#TITLE" "${title}" "$index_file"
    
    final_index_file="$dir/index.html"
    mv "$index_file" "$final_index_file"
    echo "Generada web para '$title' en '$final_index_file' ... "
  fi
    
  popd > /dev/null

done
