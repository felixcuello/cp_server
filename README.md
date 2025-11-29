CP Server
----------------------------------------------

## Introducción

El proyecto se trata de un servidor para practicar programación competitiva. La idea es que los alumnos de la materia
"Estructura de Datos y Algoritmos" de la Universidad de Palermo puedan practicar los ejercicios de la materia
en un servidor donde los problemas estén controlados por nosotros.

Además cada tanto haremos algunas contests para que los alumnos vayan practicando lo aprendido contrarreloj.

## Instalación

En realidad la instalación por ahora es muy sencilla, son un par de containers de docker, para crear y correr los
servicios de docker simplemente hay que correr `make` y leer la documentación que aparece en pantalla.

## Contests y Problemas

El servidor soporta dos formas de organizar problemas:

1. **Problemas Standalone** (directorio `app/problems/`): Problemas individuales no asociados a ningún contest
2. **Problemas de Contest** (directorio `app/contests/`): Problemas organizados por contest con metadata completa

Para más información sobre cómo crear y gestionar contests, ver [CONTESTS.md](CONTESTS.md).

### Comandos Rápidos

```bash
# Crear contests desde app/contests/
make contests-create

# Actualizar contests existentes
make contests-update

# Ver todos los comandos disponibles
make
```

## Lenguajes de Programación
El siguiente es el listado de lenguajes de programación soportados. Para los contests y los envíos de los estudiantes
sólo vamos a aceptar los lenguajes dados en la materia. Queremos que el servidor pueda utilizarse con otros lenguajes.

Los lenguajes implementados hasta ahora son los siguientes:

- [X] Ruby
- [X] C
- [X] C++
- [X] Javascript
- [X] Python
- [ ] Go
- [ ] Java

## Ejecución en Sandbox
La ejecución de los problemas se realiza en un sandbox para evitar que haya usuarios maliciosos perjudicando el servidor o intentando romper los envíos de otros jugdadores. Toda la ejecución se hace con [nsjail](https://nsjail.dev/). Este es un servidor semi-público, con lo cual todos los usuarios ingresados están registrados a mano, por lo que cualquier intento de romper el server es causa suficiente para eliminar las cuentas.

## Problemas
Va a haber problemas de todo tipo, pero mayormente son problemas de algoritmos para estudiantes de las carreras de Computación.
