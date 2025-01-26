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
  - [X] (UI/UX) Agregar estilos para mostrar el listado de problemas
  - [X] Filtrar lista de problemas
    - [X] Por dificultad
    - [X] Por tags
    - [ ] Agregar unit tests para los filtros
  - [X] Crear una rake task para agregar problemas desde problems/problems.json
    - [ ] crear un unit test para chequear que corra
    - [X] agregar problemas de ejemplo en problems/something.json
    - [X] correr la rake task
  - [ ] Verificar alguna forma de mostrar el problema (markdown? / Latex?)

- [ ] Ejecutar Problemas
    - [X] Agregar una tabla para cada lenguaje de programación disponible
        - [X] Nombre
        - [X] Forma de ejecución
    - [X] Agregar sidekiq (o algo por el estilo) para poder correr los tests en background
        - [X] Agregar redis
        - [X] Agregar sidekiq
    - [X] Agregar un form de submission
    - [X] Clean up del form luego del submission
    - [X] Agregar un service object para encolar problemas
    - [X] Hacer que sidekiq encole los problemas
    - [X] Hacer que se ejecute el problema [interprete]
    - [X] Chequear cómo verificar el output de una ejecución
    - [X] Cambiar el estado de la submission de acuerdo al resultado
      - [X] Presentation Error
      - [X] Wrong Answer
      - [X] Time Limit Exceeded
      - [X] Memory Limit Exceeded
      - [X] Running
      - [X] Accepted
    - [X] Profile
        - [X] Mostrar el perfil de usuario (problemas resueltos, easy, medium and hard)
        - [X] Mostrar los lenguajes usados
    - [X] Hacer que se compile y ejecute el problema [compilado]
    - [ ] Agregar lenguajes
        - [X] Ruby
        - [X] C
        - [ ] C++
        - [ ] Go
        - [ ] Java
        - [ ] Javascript
        - [ ] Python
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
