export PATH=/opt/homebrew/bin:/opt/homebrew/sbin:$PATH
export PATH=/opt/homebrew/include:/opt/homebrew/Cellar:/opt/homebrew/lib:$PATH
export PATH=/opt/homebrew/Cellar/libsixel/1.10.3_1:$PATH
export HOMEBREW_NO_AUTO_UPDATE=1

if [[ -r "/opt/homebrew/etc/profile.d/bash_completion.sh" ]]; then
    . "/opt/homebrew/etc/profile.d/bash_completion.sh"
fi

parse_git_branch() {
     git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/(\1)/'
}

export PS1="\u@\h \[\e[32m\]\w \[\e[91m\]\$(parse_git_branch)\[\e[00m\]$ "

#===================================== aliases =====================================
alias python=python3.12
alias python3=python3.12

alias ls="ls -G"
alias la="ls -aG"
alias ll="ls -laG"
alias c=clear
alias clr=clear

alias dc="cd ~/Documents/"
alias dcl="cd ~/Documents/local"
alias dsk="cd ~/Desktop/"

alias g=git
alias gs="git status"

alias make="bear -- make"

#==================================== functions ====================================
function error() {
    echo -e "$@" >> /dev/stderr
}

function mkdircd() {
    mkdir -p "$@" && cd "${@:-1}"
}

function bash-conf() {
    local conf="$(readlink -f ~/.bash_profile)"

    nvim "$conf"
    source "$conf"
}

function start-docker() {
    $(command docker info &>/dev/null) && return 0

    echo -en "Docker is not running\nStarting docker application"
    open -jg -a /Applications/Docker.app || {
        error "Failed to open Docker.app"
        return 1
    }

    local attempts=0
    local max_attempts=10

    while ! command docker info &>/dev/null && [ $attempts -lt $max_attempts ]; do
        sleep 1 && echo -n "."
        attempts=$((attempts + 1))
    done
    echo ""

    if [ $attempts -eq $max_attempts ]; then
        error "Failed to start Docker after $max_attempts seconds"
        return 1
    fi

    return 0
}

function docker() {
    start-docker || return 1

    command docker "$@"
    return $?
}

function start-container() {
    local container_name=$1
    local timeout=5

    [ -z "$container_name" ] && { error "Bad container name" && return 1; }

    start-docker || return 1

    if ! command docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        error "Container $container_name doesn't exist"
        return 1
    fi

    if command docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo "Container $container_name is already started"
    else
        echo "Starting container $container_name"
        local output
        output=$(command docker start "$container_name" 2>&1 >/dev/tty) || {
            error "\tFailed to start container:\n\`\`\`\n$output\n\`\`\`"
            return 1
        }
    fi

    local elapsed=0
    while \
        ! command docker ps --filter "name=$1" --format '{{.Status}}' \
        | grep -q "Up";
    do
        sleep 1 && echo -n "."
        elapsed=$((elapsed + 1))

        [ $elapsed -ge $timeout ] && { error "Failed" && return 1; }
    done
    echo ""

    DOCKER_CLI_HINTS=false command docker exec -it "$container_name" bash || return 1
    return 0
}

# quick launch specific container
alias ubuntud="start-container ubuntud"

function mdl() {
    pandoc -t plain "$1" | less
}

function togif() {
    local source
    local output

    source=$(readlink -f "$1") || {
        echo "File '$1' doesn't exist"
    }

    if [ "x$2" != "x" ]; then
        local path=$(dirname "$2")
        if [ ! -d "$path" ]; then
            echo "Directory '"$path"' doesn't exist, aborting..."
            return 1
        fi

        output=$2
    fi

    local filename=${source%.*}
    filename=${filename##*/}
    local target="${filename}.gif"

    ffmpeg \
        -i "$source" \
        -vf "fps=10,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        -loop 0 \
        "$target" \
    || return 1

    if [ "x$output" != "x" ]; then
        mv "$target" "$output"
    fi

    return 0
}
