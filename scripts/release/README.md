# Lockstep release do rust_userspace_hub

O conjunto de release possui nove repositórios e nove crates:

- `userspace_hub` (superproject/workspace);
- `ample`;
- `computers`;
- `humans`;
- `kernelspace`;
- `twins`;
- `userspace`;
- `userspace_build`;
- `webspace`.

A regra é simples: uma release do conjunto possui **uma única versão `X.Y.Z`**.
Não existe release parcial intencional: todos os nove `package.version` e todas as
dependências internas com `version = "..."` devem convergir para o mesmo número.

## Dois papéis dos submodules

O hub registra cada crate por um gitlink, portanto o commit do superproject continua
reprodutível: cada `crates/*` aponta para um SHA exato.

Isso não exige trabalhar em detached HEAD. Para transformar os oito checkouts em
repositórios de trabalho normais:

```bash
bash scripts/submodules/attach.sh
```

O comando cria/usa a branch definida em `.gitmodules` (hoje `main`), configura
`origin/main` como upstream e preserva, quando seguro, o SHA fixado pelo hub.

Para também avançar cada branch até o remoto:

```bash
bash scripts/submodules/attach.sh --pull
```

Depois disso, o fluxo cotidiano funciona normalmente:

```bash
cd crates/ample
git status
git pull --ff-only
# editar
git add .
git commit
git push
```

Ao voltar para a raiz, o hub verá que o gitlink de `crates/ample` mudou. Esse novo
SHA só passa a fazer parte do estado reprodutível do workspace quando o superproject
o registra em um commit.

## Inspeção de versão

```bash
python3 scripts/release/lockstep.py status
```

O comando lista as nove versões e verifica também se dependências entre crates do
conjunto:

1. declaram uma versão de registry compatível com a versão lockstep;
2. não embutem `path` para repositórios irmãos nos manifests dos filhos;
3. são sobrescritas localmente pelo `[patch.crates-io]` canônico do hub.

A próxima versão patch é calculada a partir da maior versão atual:

```bash
python3 scripts/release/lockstep.py next-patch
```

## Preparação de uma release

Comece com o hub e os oito submodules limpos e anexados às branches configuradas:

```bash
bash scripts/submodules/attach.sh
python3 scripts/release/lockstep.py status
```

Depois escolha explicitamente a versão calculada/revisada:

```bash
python3 scripts/release/lockstep.py set-version X.Y.Z
```

Esse comando altera apenas manifests. Ele não cria commits, não faz push, não cria
tags e não publica.

Revise as diferenças em cada repositório, faça os commits/pushes das oito crates e,
por último, registre no hub o seu próprio `Cargo.toml` e os oito novos gitlinks.

## Publicação

A publicação é coordenada pelo hub:

```bash
python3 scripts/release/publish.py
```

Sem opções, esse comando é um dry-run operacional: exige lockstep, exige repositórios
limpos/anexados, valida o workspace e gera os pacotes localmente sem publicar.

A publicação real exige:

```bash
CARGO_REGISTRY_TOKEN=... \
python3 scripts/release/publish.py --execute
```

A ordem é calculada a partir do grafo de dependências internas. Uma crate dependente
só é publicada depois de suas dependências do conjunto. Depois de cada `cargo publish`,
o coordenador espera `cargo info crate@X.Y.Z` reconhecer a versão antes de avançar.

Se uma publicação intermediária tiver sido concluída e uma posterior falhar, espere a
propagação do registry e retome a mesma versão com:

```bash
CARGO_REGISTRY_TOKEN=... \
python3 scripts/release/publish.py --execute --resume
```

`--resume` pula somente crates da versão atual que o Cargo já consegue enxergar.

## Invariantes

Antes de uma publicação real:

- são exatamente nove crates na unidade de release;
- os nove `package.version` são idênticos;
- versões declaradas das dependências internas são idênticas à versão da release;
- cada repositório filho continua compilável isoladamente usando crates.io;
- os manifests dos filhos não dependem de caminhos para irmãos;
- o `[patch.crates-io]` do hub resolve as oito crates para `crates/*`;
- nenhum dos oito submodules está em detached HEAD;
- hub e submodules estão limpos;
- cada HEAD de release já coincide com sua branch remota correspondente;
- o hub registra os SHAs exatos que serão publicados;
- o publish segue a ordem topológica do grafo.

Os manifests dos oito repositórios filhos são registry-first: um clone isolado resolve
suas dependências internas pelo crates.io. Quando esses mesmos repositórios são membros
do `rust_userspace_hub`, o `[patch.crates-io]` definido no manifest raiz substitui
essas dependências pelas cópias locais em `crates/*`.

Assim, portabilidade e desenvolvimento integrado não competem: o filho não precisa
conhecer a posição do hub, enquanto o hub continua testando exatamente os commits
registrados pelos seus gitlinks.
