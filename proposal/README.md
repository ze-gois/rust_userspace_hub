# Proposta de workflow para releases

Este diretório contém uma proposta executável para organizar o desenvolvimento, a integração e a publicação das crates do `rust_userspace_hub`.

Nenhum script deste diretório é executado automaticamente. A adoção deve ser feita em duas etapas:

1. scripts na raiz de `proposal/`: ajustes únicos e validação inicial;
2. scripts em `proposal/publish/`: fluxo recorrente de cada publicação.

## Realidade do projeto

O `rust_userspace_hub` é um repositório de gerenciamento e publicação. Ele também contém um workspace Cargo para validar o conjunto, mas seus membros são repositórios Git independentes montados como submodules:

```text
rust_userspace_hub/
├── crates/ample           -> rust_ample
├── crates/computers       -> rust_computers
├── crates/humans          -> rust_humans
├── crates/kernelspace     -> rust_kernelspace
├── crates/twins           -> rust_twins
├── crates/userspace       -> rust_userspace
├── crates/userspace_build -> rust_userspace_build
└── crates/webspace        -> rust_webspace
```

Há três cópias administrativas/desenvolvimento que não devem ser confundidas:

```text
/home/gois/github/ample/
  fonte oficial de desenvolvimento local da crate ample
  push para git@github.com:ze-gois/rust_ample

/home/gois/github/rust_ample/
  clone administrativo separado do mesmo remoto
  não é fonte de desenvolvimento nem deve ser publicado diretamente

/home/gois/github/rust_userspace_hub/crates/ample/
  submodule de gestão/publicação
  recebe um commit já enviado ao remoto e é usado para package/publish
```

O padrão é equivalente para as demais crates.

As responsabilidades ficam assim:

- o diretório de desenvolvimento (`ample`, `webspace`, `humans`, etc.) é a fonte onde o código é alterado;
- o repositório remoto recebe um ou vários commits através de `git push`;
- o `rust_userspace_hub` busca e fixa o commit desejado no submodule;
- a publicação é feita a partir do submodule dentro do hub;
- `rust_userspace_hub` registra os gitlinks e publica apenas a sua própria crate quando apropriado.

O hub não deve tratar os submodules como diretórios de desenvolvimento, nem editar diretamente o código para depois tentar sincronizá-lo de volta ao repositório de origem.

## Objetivos

O workflow proposto deve:

- manter o desenvolvimento fora do `rust_userspace_hub`;
- usar os submodules apenas para gestão, validação e publicação;
- buscar do remoto os commits produzidos nos diretórios de desenvolvimento;
- manter versões publicáveis nos manifests;
- evitar dependências locais e registry duplicadas sem intenção;
- calcular a ordem de dependências antes de publicar;
- publicar somente crates alteradas;
- atualizar consumidores por Pull Request;
- atualizar os gitlinks do hub de forma revisável;
- nunca publicar ou fazer push sem uma opção explícita;
- permitir simulação completa antes de qualquer alteração.

## Modelo de dependências

As dependências internas devem preferencialmente usar `path` e `version` nos manifests das crates:

```toml
ample = { version = "0.1.129", path = "../ample" }
```

Neste modelo, o `path` é usado somente durante a validação do checkout de gestão no hub. Ao executar `cargo package`/`cargo publish`, o Cargo empacota a dependência usando a versão publicada indicada por `version`.

A alteração do manifest deve ser feita no diretório de desenvolvimento da crate e enviada ao remoto. O submodule no hub só deve receber o commit depois que ele estiver disponível no remoto.

## Fases de adoção

### Fase 1: baseline e preflight

Executar, sem `--apply`:

```bash
./proposal/01_preflight.sh
```

Esse script verifica:

- a raiz do workspace;
- a existência dos submodules;
- o estado Git do hub e dos submodules;
- branches e commits atuais;
- ferramentas mínimas disponíveis;
- metadados do workspace;
- dependências duplicadas.

O resultado deve ser revisado antes de qualquer alteração.

### Fase 2: normalização do checkout de gestão

Executar no `rust_userspace_hub`:

```bash
./proposal/02_normalize_submodules.sh
```

Por padrão, esse script apenas apresenta divergências. Para inicializar os submodules nos commits já registrados pelo hub:

```bash
./proposal/02_normalize_submodules.sh --apply
```

Ele não deve descartar alterações locais, fazer checkout de `main`, fazer pull ou fazer push. O desenvolvimento continua nos diretórios externos, como `/home/gois/github/ample`.

### Fase 3: validação das dependências

Executar:

```bash
./proposal/03_validate_dependency_graph.sh
```

O objetivo é confirmar que o workspace usa as cópias locais esperadas e que não existem versões registry duplicadas de crates internas.

Se houver dependências registry-only dentro de um submodule, a correção deve ser feita no repositório filho com `path + version`. O script não faz substituições textuais automáticas em `Cargo.toml`, porque isso poderia modificar dependências em categorias ou targets errados.

### Fase 4: publicação recorrente

O fluxo recorrente está em `proposal/publish/`.

Fluxo recomendado para uma alteração desenvolvida em `ample`:

```text
editar /home/gois/github/ample
  ↓
commit(s) de desenvolvimento
  ↓
git push para rust_ample
  ↓
sincronizar crates/ample no hub
  ↓
plan
  ↓
check
  ↓
package/publish a partir do hub
  ↓
atualizar consumidores e gitlinks
```

Para um grafo com várias crates:

```text
sincronizar commits dos submodules
  ↓
plan
  ↓
check
  ↓
publicar dependências necessárias
  ↓
atualizar consumidores
  ↓
validar o hub
  ↓
publicar userspace_hub

Comandos:

```bash
./proposal/publish/plan.sh
./proposal/publish/check.sh
./proposal/publish/sync-submodule.sh \
  --submodule crates/ample \
  --branch main \
  --dry-run
./proposal/publish/publish.sh --crate ample --dry-run
./proposal/publish/update-hub.sh \
  --submodule crates/ample \
  --commit <commit> \
  --dry-run
```

A publicação real exige `--execute`:

```bash
./proposal/publish/publish.sh --crate ample --execute
```

## Política de release

### Não fazer bump global por push

Um push em `ample` para `rust_ample` não publica automaticamente a crate. Ele apenas disponibiliza o commit para o repositório de gestão.

Um push em `zegois_music` ou no hub também não deve republicar todas as dependências. Uma crate recebe nova versão somente quando existe uma alteração que justifique o release.

O fluxo de publicação sempre parte do checkout administrativo dentro do hub, nunca diretamente do diretório de desenvolvimento.

### Ordem topológica

A ordem efetiva deve ser obtida de `cargo metadata` e validada antes da publicação. Uma ordem típica poderá ser:

```text
ample
  ↓
userspace_build
  ↓
userspace / humans
  ↓
kernelspace / webspace / twins
  ↓
userspace_hub
```

A ordem não deve ser codificada como uma sequência cega: o grafo real dos manifests é a fonte de verdade.

### SemVer

- `patch`: correções compatíveis;
- `minor`: funcionalidades compatíveis;
- `major`: breaking changes.

O workflow deve incluir uma verificação de compatibilidade, como `cargo-semver-checks`, quando a ferramenta estiver instalada no CI.

### Cargo.lock

A política proposta é:

- manter `Cargo.lock` no `userspace_hub` e em aplicações/binários;
- avaliar não versionar `Cargo.lock` nas crates de biblioteca;
- atualizar locks somente depois que as versões publicadas necessárias existirem.

A decisão final deve ser aplicada de forma consistente em todos os repositórios.

## Segurança operacional

Todos os scripts devem:

- iniciar com `set -eu` ou equivalente;
- derivar a raiz do repositório do próprio script;
- recusar worktrees sujos quando a operação puder modificar arquivos;
- não fazer `git push` implicitamente;
- não publicar sem `--execute`;
- verificar a branch permitida;
- verificar a presença de `CARGO_REGISTRY_TOKEN` somente no momento da publicação;
- parar se uma dependência necessária não estiver disponível no crates.io;
- informar o último passo concluído em caso de falha.

O crates.io não oferece uma transação para publicar várias crates. Se uma publicação intermediária for concluída e uma posterior falhar, o workflow deve registrar o ponto de retomada, nunca tentar reutilizar a mesma versão.

## Git e submodules

Um submodule é um gitlink no repositório pai. Fazer commit dentro de `/home/gois/github/ample` e executar push para `rust_ample` não atualiza automaticamente `rust_userspace_hub`.

Depois que os commits de desenvolvimento estiverem no remoto, sincronizar o checkout administrativo:

```bash
./proposal/publish/sync-submodule.sh \
  --submodule crates/ample \
  --branch main \
  --apply
```

Depois revisar o gitlink:

```bash
git diff --submodule
./proposal/publish/update-hub.sh \
  --submodule crates/ample \
  --commit <commit-publicado> \
  --apply
git diff --cached --submodule
```

O commit do hub deve ser feito manualmente ou através de uma Pull Request. O branch definido em `.gitmodules` não faz o submodule acompanhar a branch automaticamente.

O clone externo `/home/gois/github/rust_ample` não participa desse fluxo e não deve ser usado como origem de publicação.

## CI proposto

O CI do repositório de desenvolvimento valida a alteração antes do push, quando aplicável. O CI do hub valida o commit sincronizado antes da publicação.

Cada repositório de crate deve validar:

```bash
cargo fmt --all -- --check
cargo check
cargo test
cargo clippy --all-targets
cargo package --verify
```

O hub deve validar:

```bash
git submodule status --recursive
cargo check --workspace
cargo test --workspace
cargo tree --workspace --duplicates
```

A publicação deve ser um job separado do CI normal e usar o segredo:

```text
CARGO_REGISTRY_TOKEN
```

O token nunca deve aparecer em manifests, scripts ou logs.

## Ferramenta de release

A proposta permite começar com `cargo-release`, que já está presente na configuração atual, mas ele deve ser executado no repositório dono de cada crate.

Como evolução, `release-plz` pode substituir a coordenação manual, criando Pull Requests de release e atualizando dependências. Nenhuma ferramenta deve publicar todos os submodules a partir do hub sem compreender a fronteira Git entre eles.

## Critérios de aceitação

A adoção estará pronta quando:

1. um clone limpo do hub conseguir inicializar submodules e executar a validação administrativa;
2. o grafo não apresentar versões registry e locais duplicadas sem intenção;
3. `plan.sh` não modificar arquivos, commits, tags ou registry;
4. `check.sh` falhar com mensagem clara quando houver submodule sujo;
5. `publish.sh` exigir `--execute` para publicar;
6. uma crate não alterada não receber bump automático;
7. o hub registrar explicitamente cada novo commit de submodule;
8. uma dependência não publicada bloquear o consumidor;
9. `userspace_hub` só for publicado depois das crates necessárias;
10. nenhum script depender de caminhos absolutos da máquina, como `/backup/rustics/userspace_hub`.

## Fora do escopo inicial

Não faz parte da primeira adoção:

- mover todas as crates para um único repositório;
- publicar automaticamente a cada push;
- alterar ou descartar alterações locais existentes;
- reescrever o histórico dos repositórios;
- fazer push automático para branches de produção;
- manter versões artificialmente iguais quando não houver mudança de código.
