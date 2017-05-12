This script makes it possible to upload documents to the the Overleaf gallery via the HTTP interface at <https://www.overleaf.com/docs/DOCUMENT_ID/exports/gallery> in an automated fashion. You invoke the script as `overleaf-upload.sh SCRIPT`, where `SCRIPT` is a shell script that defines variables describing your package. The variable names are an upper-case variant of the HTML form element names at <https://www.overleaf.com/docs/DOCUMENT_ID/exports/gallery>; inspect the example shell script `example.def` for more information.

The `xmllint` and `curl` binaries are required.
