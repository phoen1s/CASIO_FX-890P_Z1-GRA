# Formateo de tarjeta SD en la CASIO FX-890P y modelos compatibles.

Para utilizar una tarjeta SD de 2GB como unidad de almacenamiento en la CASIO FX-890P y modelos compatibles se debe de formatear de la siguiente manera para que sea 100% compatible y funcional: <br>

Material necesario: <br>
Solo logré preparar correctamente la tarjeta SD desde macOS utilizando la Terminal, ya que todos mis intentos anteriores en otros sistemas operativos no dieron resultado. Probé con Windows y también con MS-DOS, pero no conseguí que la tarjeta quedara en el formato exacto que necesitaba para su correcto funcionamiento y compatibilidad. Incluso utilicé varios programas de terceros ampliamente conocidos, como Rufus, SD Card Formatter, entre otros, y tampoco logre la compatibilidad total de la CASIO al PC. <br>

La única manera en que logré que la tarjeta SD quedara 100% compatible y formateada en FAT16 con el sistema de particionado MBR (Master Boot Record) fue mediante los siguientes pasos desde la Terminal de macOS: <br>

 1. Busca el SD
 diskutil list

 2. Desmonta la unidad por ejemplo si el SD esta en /dev/disk6
 diskutil unmountDisk /dev/disk6

 3. Inicializar el disco con una tabla de particiones DOS: <br>
 fdisk: 1> edit 1 <br>
 Esto edita la partición 1. Si no existe, se crea al salir. <br>

 4. Configurar los campos de la partición: <br>
 Partition id: 06 <br>
 Do you wish to edit in CHS mode? [n] n <br>
 Offset: 63 <br>
 Size: 3921857 <br>

 5. Después de editar la partición, asegurate de marcarla como activa: <br>
 flag 1

 6. Grabar y salir: <br>
 write <br>
 quit <br>

 7. Desmontás el disco si no está desmontado: <br>
 diskutil unmountDisk /dev/disk4 <br>

 8. Y luego lo formateás en FAT16: <br>
 sudo newfs_msdos -F 16 -v SDCARD -S 512 -c 64 /dev/disk4s1 <br>

 	•	-F 16 → Formato FAT16 <br>
 	•	-v SDCARD → Nombre del volumen <br>
 	•	-S 512 → Sector físico de 512 bytes <br>
 	•	-c 64 → 64 sectores por clúster = 32 KB por clúster <br>
 	•	/dev/disk4s1 → Partición creada en el paso anterior <br>

Ahora, desde macOS, puedes copiar archivos y crear directorios que la CASIO reconocerá. <br>
Es altamente recomendable copiar y crear directorios desde la terminal con los comandos mcopy y mmd, para evitar que el sistema meta archivos ocultos y metadatos, de todas formas con la aplicacion FMS puedes desde la CASIO borrar esos archivos inecesarios. <br>
Luego, para navegar por los directorios desde la CASIO, escribe por ejemplo desde la unidad E0: <br>
CD GAMES <br>
De esta manera, entrarás en el directorio GAMES, y para volver al directorio raíz principal, debes utilizar el símbolo yen (¥): <br>
CD ¥ <br>

VIDEO: <br>
https://www.youtube.com/watch?v=tvQqj17PYp8



 
	
	
