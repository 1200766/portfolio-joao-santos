# Relatório sanitizado

## Âmbito

O trabalho analisou riscos de confidencialidade, integridade e autenticação em protocolos utilizados num ecossistema biomédico distribuído. As experiências decorreram em ambiente laboratorial e incidiram sobre HTTP e DICOM.

## HTTP

A inspeção de tráfego sem TLS mostrou que pedidos, respostas, cabeçalhos, cookies e credenciais podem ficar observáveis para quem tenha acesso ao segmento de rede. Filtros e estatísticas permitiram isolar conversações, endpoints e volumes relevantes.

As medidas propostas incluem HTTPS/TLS, cookies com atributos seguros, gestão de sessão, autenticação forte, segmentação e redução de dados sensíveis em trânsito.

## DICOM

Foram exercitadas associações DICOM e operações C-STORE, C-FIND e C-MOVE em cenários de loopback e entre componentes de laboratório. A análise mostrou que uma configuração sem proteção pode revelar metadados, padrões de utilização e conteúdo clínico.

As medidas propostas incluem DICOM sobre TLS, autenticação mútua quando aplicável, controlo de AE Titles e endereços, segmentação, listas de acesso, logging, minimização e utilização exclusiva de objetos sintéticos ou devidamente anonimizados.

## Código vulnerável

`VulnerablePing.java` concatena entrada num comando executado por `/bin/sh -c`, criando uma vulnerabilidade de injeção de comandos. `SafePing.java` evita a shell, valida o formato e passa o destino como argumento separado.

## Limitações

- observações restritas ao laboratório e às ferramentas usadas;
- ausência de teste de uma infraestrutura clínica real;
- capturas e configurações não são publicadas por conterem informação operacional;
- conclusões não substituem uma auditoria de segurança ou avaliação de conformidade.
