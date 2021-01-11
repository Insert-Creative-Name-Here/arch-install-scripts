#!/usr/bin/sh

initialization() {
    # For those unfamiliar, what I'm doing is basically an if statement:
    #[[ condition ]]
    #  && statement
    # which basically tells the shell that "if the first command succeeds, run
    # the second one", because, plot twist, the [[ is actually a command

    # So, if there isn't a directory, make it and output something to the
    # terminnal
    [[ ! -d $HOME/.config ]]
        && mkdir ${HOME}/.config
        && echo "mkdir ${HOME}/.config"

    [[ -z ${ZDOTDIR} ]] || ZDOTDIR="$HOME/.config/zsh"
    # Here, if the directory does not exist but program does, make the directory
    # and output something to the command line
    [[ ! -d ${ZDOTDIR}]] && command -v zsh &> /dev/null
        && mkdir ${ZDOTDIR}/zsh
        && echo "mkdir ${ZDOTDIR}/zsh"

    [[ ! -d ${HOME}/.config/i3 ]] && command -v i3 &> /dev/null
        && mkdir ${HOME}/.config/i3
        && echo "mkdir ${HOME}/.config/i3"
    [[ ! -d ${HOME}/.config/vim ]] && command -v vim &> /dev/null
        && mkdir ${HOME}/.config/vim
        && echo "mkdir ${HOME}/.config/vim"

    [[ ! -d ${HOME}/.config/nvim ]] && command -v nvim &> /dev/null
        && mkdir ${HOME}/.config/nvim
        && echo "mkdir ${HOME}/.config/nvim"

    [[ ! -d ${HOME}/.config/git ]] && command -v git &> /dev/null
        && mkdir ${HOME}/.config/git
        && echo "mkdir ${HOME}/.config/git"
}

clone_with_git() {
    declare -r repo="https://github.com/Insert-Creative-Name-Here/Insert-Creative-Name-Here.git"
    declare -r repoDirName="Insert-Creativ-Name-Here"

    if ! command -v git 2>/dev/null; then
        echo "git not installed; installing..."
        echo | sudo pacman -S git
    fi

    declare -r workspace="projects"

    [[ -d ${HOME}/${workspace} ]] || mkdir ${HOME}/${workspace}

    cd ${HOME}/${workspace}
    git clone ${repo}

    cd ${repoDirName}
}

process_installed_files() {
    # Everything is a file, even directories
    for FILE in *; do
        # If current object is a directory, look inside it
        if [[ -d ${FILE} ]]; then
            for FILE_IN_DIR in ${FILE}/*; do
                processRules ${FILE_IN_DIR}
            done
        else
            processRules ${FILE}
        fi
    done
}

zsh_files=( 
    ".zshrc" 
    ".zlogin" 
    ".zshenv"
    ".p10k.zsh"
    "aliasrc.sh"
    "gitaliases.sh"
)

process_rules() {
    # In an ideal world, everything would follow the XDG specification; but they
    # don't, sadly.

    # zsh doesn't follow XDG by default, but I've configured it so that it
    # does
    [[ ${zsh_files[@]} =~ ${1} ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/zsh/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/zsh/${1}"
        && return 0
    
    [[ ${1} == "picom.conf" ]] 
        && ln -s $(pwd)/${1} ${HOME}/.config/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/${1}"
        && return 0

    [[ $1 == "vimrc" ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/vim/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/vim/${1}"
        && return 0

    [[ $1 == "init.vim" ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/nvim/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/nvim/${1}"
        && return 0

    # This is a special case where the program and the config file's name
    # doesn't match up
    [[ ${1} == ".gitconfig" ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/git/config
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/git/config"
        && return 0

    [[ ${1} == "i3conf" ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/i3/config
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/i3/config"
        && return 0

    [[ $1 =~ "wallpaper" ]]
        && ln -s $(pwd)/${1} ${HOME}/.config/i3/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/i3/${1}"
        && return 0

    declare programName = ${1%.*}
        # Here, we should always end up with a directory
        && [[ ! -d ${HOME}/.config/${programName} ]]
        || mkdir ${HOME}/.config/${programName} 2> /dev/null
        && ln -s $(pwd)/${1} ${HOME}/.config/${programName}/${1}
        && echo "ln -s $(pwd)/${1} ${HOME}/.config/${programName}/${1}"
        && return 0

    return 1
}

initialization
clone_with_git
process_installed_files
