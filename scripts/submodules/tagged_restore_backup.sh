#!/bin/bash
set -e

submodules=(ample build crate hub kernel)

usage() {
    echo "Uso:"
    echo "  $0 <branch_name> <tag_de_backup>   # Restaura um branch a partir de uma tag"
    echo "  $0 list-branches                   # Lista branches locais e remotos"
    echo "  $0 list-tags                       # Lista tags de backup disponíveis"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

mode="$1"

case "$mode" in
    list-branches)
        echo "=== Branches disponíveis ==="
        for repo in "${submodules[@]}" .; do
            if [ "$repo" = "." ]; then
                echo "--- Repositório pai ---"
            else
                echo "--- Submódulo: $repo ---"
                cd "$repo"
            fi

            git fetch --all --quiet
            echo "Locais:"
            git branch
            echo "Remotos:"
            git branch -r
            echo

            [ "$repo" != "." ] && cd ..
        done
        ;;

    list-tags)
        echo "=== Tags de backup disponíveis ==="
        for repo in "${submodules[@]}" .; do
            if [ "$repo" = "." ]; then
                echo "--- Repositório pai ---"
            else
                echo "--- Submódulo: $repo ---"
                cd "$repo"
            fi

            git fetch --tags --quiet
            git tag | grep "backup" || echo "(nenhuma tag encontrada)"
            echo

            [ "$repo" != "." ] && cd ..
        done
        ;;

    *)
        if [ $# -ne 2 ]; then
            usage
        fi

        branch_name="$1"
        tag="$2"

        echo "=== Restaurando branch '$branch_name' a partir da tag '$tag' ==="

        for sub in "${submodules[@]}"; do
            echo ">>> Submódulo: $sub"
            cd "$sub"

            git fetch --tags
            git checkout "$tag"
            git switch -C "$branch_name"
            git push --force --set-upstream origin "$branch_name"

            echo "Submódulo '$sub' restaurado para $tag e branch '$branch_name' atualizada."
            cd ..
        done

        echo "=== Atualizando repositório pai ==="
        git switch -C "$branch_name"
        git add "${submodules[@]}"
        git commit -m "Restore $branch_name branch from backup tag $tag"
        git push --force --set-upstream origin "$branch_name"

        echo "=== Restauração completa! Todos os submódulos e repositório pai apontam para a tag '$tag' ==="
        ;;
esac
