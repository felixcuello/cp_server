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
  - [ ] Mostrar lista de problemas (#index)
  - [ ] Mostrar un problema (#show)
    - [ ] Verificar alguna forma de mostrar el problema (markdown? / Latex?)
  - [ ] Tener tests para los problemas
    - [ ] Correr los tests
    - [ ] Ver los resultados de los tests
      - [ ] Presentation Error
      - [ ] Wrong Answer
      - [ ] Time Limit Exceeded
      - [ ] Memory Limit Exceeded
      - [ ] Accepted

- [ ] Submit form
  - [ ] Agregar soporte para lenguaje (C / C++ / Ruby / ... etc.)
  - [ ] Agregar sidekiq (o algo por el estilo) para poder correr los tests en background

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
