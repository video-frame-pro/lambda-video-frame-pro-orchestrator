# lambda-video-frame-pro-orchestrator

### Resumo dos Comandos

### Testes Unitários

1. Rode o bloco para instalar as dependências de testes, executar os testes e gerar o relatório de cobertura:

```sh
find tests -name 'requirements.txt' -exec pip install -r {} +
pip install coverage coverage-badge
coverage run -m unittest discover -s tests -p '*_test.py'
coverage report -m
coverage html  
```