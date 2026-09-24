# Scripts operacionais

O `rust_userspace_hub` possui duas responsabilidades operacionais separadas:

1. anexar os oito submodules a branches Git normais;
2. coordenar os nove crates como uma unidade de publicação no crates.io.

Não há mais um segundo fluxo de release baseado em `cargo-release`, scripts `proposal/`
ou scripts especializados em apenas quatro submodules.

## Submodules

```bash
bash scripts/submodules/attach.sh
```

Inicializa apenas os submodules diretos que estiverem ausentes, anexa cada checkout à
branch configurada em `.gitmodules` e preserva o SHA fixado pelo hub quando isso puder
ser feito sem descartar história local.

Para também avançar branches por fast-forward:

```bash
bash scripts/submodules/attach.sh --pull
```

O hub continua armazenando um gitlink (SHA exato) mesmo quando o checkout do submodule
está em `main`.

## Unidade de publicação

A interface canônica é:

```bash
python3 scripts/publish.py plan
python3 scripts/publish.py next-patch
python3 scripts/publish.py prepare X.Y.Z
python3 scripts/publish.py check
python3 scripts/publish.py publish
python3 scripts/publish.py publish --execute
```

A unidade é composta exatamente por:

- `userspace_hub`;
- `ample`;
- `computers`;
- `humans`;
- `kernelspace`;
- `twins`;
- `userspace`;
- `userspace_build`;
- `webspace`.

### Contrato de dependências

Cada repositório filho é registry-first. Um clone isolado declara somente versões do
crates.io:

```toml
[dependencies]
ample = "0.2.2"
```

Somente o hub escolhe as cópias locais:

```toml
[patch.crates-io]
ample = { path = "crates/ample" }
```

A unidade rejeita dependências internas `path`/`git` nos manifests e verifica que o
`[patch.crates-io]` do hub cobre os oito filhos em seus paths canônicos.

### `plan`

Mostra as nove versões, o grafo interno, a ordem topológica e o próximo patch sugerido.
Não modifica arquivos nem consulta o registry.

### `prepare X.Y.Z`

Exige worktrees limpos e submodules anexados às branches configuradas. Atualiza:

- os nove `package.version`;
- todas as requirements das dependências internas;
- o `Cargo.lock` do hub.

A operação não cria commit, tag, push ou publicação. Se a reescrita ou a geração do
lock falhar, os manifests e o lock são restaurados.

Depois de `prepare`, os commits continuam pertencendo aos nove repositórios. Faça os
commits/pushes dos oito filhos, registre os oito novos gitlinks no hub e leve o commit
do hub até `main`.

### `check`

Exige lockstep e executa:

```text
cargo fmt --all -- --check
cargo check --workspace
cargo package --registry crates-io --no-verify --allow-dirty
```

O `--no-verify` do empacotamento é intencional: antes da publicação, as dependências
da nova versão ainda não existem no crates.io. A validação de código acontece contra
as cópias locais fornecidas por `[patch.crates-io]`.

### `publish`

Sem `--execute`, é um dry-run de publicação: exige os nove repos limpos, `main`
sincronizada com os remotos, gitlinks exatos, executa os checks e consulta o estado da
versão no crates.io.

Com:

```bash
python3 scripts/publish.py publish --execute
```

cada crate é publicada sequencialmente na ordem calculada pelo grafo. Depois de cada
upload, a unidade aguarda a versão ficar visível tanto na API do crates.io quanto ao
Cargo antes de liberar seus consumidores.

O crates.io não oferece transação multi-crate. Se houver falha depois de uma publicação
parcial, retome a mesma versão com:

```bash
python3 scripts/publish.py publish --execute --resume
```

`--resume` aceita somente um prefixo da ordem produzida pela própria unidade. Um estado
do registry com crates posteriores publicadas enquanto anteriores estão ausentes é
bloqueado para evitar que o script tente adivinhar como aquele estado foi criado.

## Invariantes de publicação real

Antes do primeiro upload a unidade exige:

- exatamente os nove package names esperados;
- exatamente oito submodules diretos e oito membros do workspace;
- os nove `package.version` iguais;
- todas as dependências internas na mesma versão;
- nenhum `path` ou `git` interno nos manifests;
- os oito patches locais presentes somente no hub;
- todos os worktrees limpos e em branches anexadas;
- hub em `main` e cada child na branch configurada (`main`);
- cada HEAD igual ao respectivo `origin/<branch>`;
- cada gitlink do hub igual ao HEAD do child;
- grafo interno acíclico.

A ordem não é codificada manualmente: é derivada das dependências normais e de build
presentes nos manifests.


## Bootstrap copy

`userspace_build` is the bootstrap copy of `userspace`. It is not maintained
independently.

Every:

```bash
python3 scripts/publish.py prepare X.Y.Z
```

first projects `crates/userspace/src/**` and `crates/userspace/linker.ld` into
`crates/userspace_build`. Rust paths referring to the canonical package are
rewritten from `userspace::` to `userspace_build::`. Files that no longer
exist in the canonical source are removed from the bootstrap copy.

`python3 scripts/publish.py check` rejects bootstrap drift before compiling the
workspace. This makes synchronization part of every coordinated version bump,
rather than a manual one-off copy.

`Cargo.toml` and `build.rs` are deliberately not mirrored: they are the
bootstrap boundary that allows `userspace_build` to exist without depending on
`userspace` as a build dependency.


## Sincronização userspace -> userspace_build

A cópia de bootstrap pode ser atualizada durante o desenvolvimento sem preparar ou publicar uma versão:

```bash
python3 scripts/userspace_build.py sync
```

Para apenas verificar se há drift:

```bash
python3 scripts/userspace_build.py check
```

O comando projeta `crates/userspace/src/**` e `crates/userspace/linker.ld` em
`crates/userspace_build`, reescrevendo caminhos Rust de `userspace::` para
`userspace_build::`. Arquivos projetados obsoletos são removidos.

`Cargo.toml` e `build.rs` de `userspace_build` não são tocados. O script não
altera versões, não cria commits ou tags, não faz push e não acessa o crates.io.
