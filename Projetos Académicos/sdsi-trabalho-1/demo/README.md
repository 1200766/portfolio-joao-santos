# Demonstração de injeção de comandos

`VulnerablePing.java` é uma reprodução intencional de uma má prática: entrega entrada não validada a uma shell. Está incluído para leitura e comparação, não como utilitário.

`SafePing.java`:

- limita o comprimento e os caracteres do destino;
- usa `ProcessBuilder` com argumentos separados;
- não invoca `/bin/sh`;
- junta stdout e stderr sem construir um comando interpretável.

As duas classes podem ser compiladas para permitir a comparação estática, mas
execute apenas a versão segura. A partir de
`Projetos Académicos/sdsi-trabalho-1/` no repositório de portefólio:

```bash
mkdir -p build
javac -Xlint:all -d build demo/VulnerablePing.java demo/SafePing.java
java -cp build SafePing
```

É necessário um JDK 8 ou superior. Os exemplos estão preparados para
macOS/Linux, devido ao uso de `ping -c` e, no exemplo vulnerável, `/bin/sh`.

Em 2026-09-14, ambas as classes compilaram sem erros nem avisos com OpenJDK
`javac 15.0.2`, também com compatibilidade Java 8. Nenhuma foi executada durante
esta validação. A compilação não valida injeção de comandos nem reproduz os
cenários ofensivos do laboratório.

Qualquer experimentação ofensiva deve ocorrer num sistema descartável, isolado
e expressamente autorizado.
