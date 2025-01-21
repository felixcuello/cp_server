CP Server
----------------------------------------------

## Introducción

El proyecto se trata de un servidor para practicar programación competitiva. La idea es que los alumnos de la materia
"Introducción a la Programación Competitiva" de la Universidad de Palermo puedan practicar los ejercicios de la materia
en un servidor.

Además cada tanto haremos algunas contests para que los alumnos vayan practicando lo aprendido contrarreloj.

## Instalación

En realidad la instalación por ahora es muy sencilla, son un par de containers de docker, para crear y correr los
servicios de docker simplemente hay que correr `make` y leer la documentación que aparece en pantalla.

## Pending

- [ ] Problemas
  - [X] Crear la tabla para los problemas
  - [X] Mostrar lista de problemas (#index)
  - [X] Mostrar un problema (#show)
  - [X] (UI/UX) Agregar estilos para mostrar el problema
  - [ ] (UI/UX) Agregar estilos para mostrar el listado de problemas
  - [ ] Filtrar lista de problems (por dificultad, por tags, por contest, sólo activos)
  - [ ] Ordenar lista de problems (por dificultad, por tags, fecha)
  - [ ] Verificar alguna forma de mostrar el problema (markdown? / Latex?)
  - [ ] Ejecutar los examples para los problemas
    - [ ] Agregar una tabla para cada lenguaje de programación disponible
        - [ ] Nombre
        - [ ] Forma de ejecución
    - [ ] Agregar sidekiq (o algo por el estilo) para poder correr los tests en background
        - [ ] Agregar redis
        - [ ] Agregar sidekiq
    - [ ] Chequear cómo verificar el output de una ejecución
    - [ ] Ejecutar cada example
    - [ ] Ver los resultados de la ejecución
      - [ ] Presentation Error
      - [ ] Wrong Answer
      - [ ] Time Limit Exceeded
      - [ ] Memory Limit Exceeded
      - [ ] Accepted
    - [ ] Result table
        - [ ] Actualización automática (hotwire?)
            - [ ] Filtros
            - [ ] Por usuario
            - [ ] Por problema
            - [ ] Por contest

- [ ] Contest
  - [ ] Crear contest (con fecha de inicio y fin)
  - [ ] Agregar usuarios al contest
  - [ ] Mostrar tabla de posiciones
  - [ ] Mostrar problemas (solo cuando la fecha de inicio esté en el pasado)
