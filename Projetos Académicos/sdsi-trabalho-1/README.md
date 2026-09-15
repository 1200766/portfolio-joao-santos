# Trabalho 1 — Vulnerabilidades em protocolos biomédicos distribuídos

[← Projetos Académicos](../README.md)

Estudo académico de segurança sobre comunicações HTTP e DICOM. O grupo capturou tráfego num laboratório controlado, aplicou filtros, comparou comunicações com e sem TLS, analisou metadados e discutiu medidas de mitigação.

> Não use estas técnicas contra sistemas sem autorização. O exemplo vulnerável é mantido apenas para estudo estático; a demonstração recomendada é a comparação com `demo/SafePing.java` num ambiente local descartável.

## Objetivos e resultados

- reconhecer credenciais, cookies e outros dados transmitidos sem proteção em HTTP;
- usar filtros e estatísticas de tráfego para sustentar uma análise;
- observar o fluxo DICOM em loopback com ferramentas como `storescu`, `findscu`, `storescp`, Orthanc e DCMQRscp;
- reconhecer que metadados e objetos DICOM podem expor informação sensível quando a comunicação não é protegida;
- comparar tráfego sem TLS com tráfego cifrado;
- demonstrar por que concatenar entrada do utilizador num comando de shell permite injeção;
- recomendar TLS, autenticação forte, segmentação, controlo de acesso, minimização e monitorização.

Nenhuma captura PCAP é distribuída nesta versão. As conclusões técnicas estão resumidas em `docs/relatorio-sanitizado.md`.

## Demonstração segura

Requisitos: JDK 8 ou superior e macOS/Linux. Os exemplos usam `ping -c` e o
ficheiro vulnerável referencia `/bin/sh`, pelo que não estão preparados para
execução direta no Windows.

```bash
mkdir -p build
javac -Xlint:all -d build demo/VulnerablePing.java demo/SafePing.java
java -cp build SafePing
```

As duas classes podem ser compiladas para comparação. Execute apenas
`SafePing`, que passa o destino como argumento direto ao processo e não invoca
uma shell. Não execute `VulnerablePing` numa máquina com dados ou acessos
relevantes.

Em 2026-09-14, os dois ficheiros Java compilaram sem erros nem avisos com OpenJDK
`javac 15.0.2`. A compilação com `--release 8 -Xlint:all` também foi aprovada.
Os ficheiros `.class` foram criados apenas numa diretoria temporária; nenhuma
das demonstrações foi executada e os cenários laboratoriais originais não
foram revalidados.

## Autoria e direitos

Consulte `AUTHORS.md`, `CONTRIBUTIONS.md` e `RIGHTS.md`.
