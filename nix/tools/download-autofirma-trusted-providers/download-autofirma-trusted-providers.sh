PRESTADORES_XML_URL="https://sedeaplicaciones.minetur.gob.es/PrestadoresDatosAbiertos/Prestadores.xml"

xmlstarlet \
	sel \
	-t \
	-m '/PRESTADORES/PRESTADOR[PrestadorCualificado[text() = "true"] and SERVICIOS/SERVICIO[Clasificacion[text() = "Certificados cualificados de Sede electrónica de la Administración Pública"]]]' \
	-o '{"name": "'    -v 'normalize-space(NombreSocial)' \
	-o '", "cif": "'     -v 'normalize-space(Cif)' \
	-o '", "website": "' -v 'normalize-space(DominioInternet)' \
	-o '", "source": "'  -v 'normalize-space(FuenteConstitucion)' \
	-o '"}' \
	-n <(curl -s --output - "$PRESTADORES_XML_URL") | sort | uniq | jq -s .

