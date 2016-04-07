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

find "$IMAGE_FOLDER"  -type d  -print0 | while IFS= read -r -d '' dir ; do
  if [ "$dir" = "$IMAGE_FOLDER" ] ; then
    continue
  fi

  title=$(basename "$dir")
  INDEX_FILE="$dir/index.html"
  echo "Generando web para '$title' en '$INDEX_FILE' ... "

  pushd "$dir" > /dev/null
  cat "$TEMPLATE_FILE" > "$INDEX_FILE"
  find . -type f  -print0 | while IFS= read -r -d '' file ; do
    file_info=$(file "$file")
    echo "$file_info" | grep -i image && insert_image "$file" "$INDEX_FILE"
  done
  sub "#TITLE" "${title}" "$INDEX_FILE"

  description_file="descripcion.txt"
  if [ -f $description_file ] ; then
    descripcion="$(cat $description_file)"
  else
    descripcion="ME FALTA DESCRIPCION PARA '$title'"
  fi
  escaped_description="$(echo "${descripcion}" | sed ':a;N;$!ba;s/\n/<br \/>/g' | sed 's/\$/\\$/g')"
  sub "#DESCRIPTION" "${escaped_description}" "$INDEX_FILE"
  popd > /dev/null

  rm "${INDEX_FILE}.bk"
done
