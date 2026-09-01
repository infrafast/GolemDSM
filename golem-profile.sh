#!/bin/sh

CONTAINER="golem-provider"
CHECK_INTERVAL=300

PROFILE="$1"

if [ "$PROFILE" = "day" ]; then
    START_HOUR=8
    END_HOUR=9
    CORES=2
    MEMORY="2GiB"
    LABEL="JOUR"
elif [ "$PROFILE" = "night" ]; then
    START_HOUR=23
    END_HOUR=24
    CORES=3
    MEMORY="4GiB"
    LABEL="NUIT"
else
    echo "Usage: $0 day|night"
    exit 1
fi

log()
{
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

inside_window()
{
    HOUR=$(date +%H)
    HOUR=$((10#$HOUR))

    if [ "$PROFILE" = "day" ]; then
        [ "$HOUR" -ge 8 ] && [ "$HOUR" -lt 9 ]
    else
        [ "$HOUR" -ge 23 ] && [ "$HOUR" -lt 24 ]
    fi
}

get_active_jobs()
{
     docker exec "$CONTAINER" golemsp status 2>/dev/null | tr -d '\r' | grep "last 1h in progress" | awk '{print $5}'
}

get_current_cores()
{
     docker exec "$CONTAINER" golemsp settings show 2>/dev/null | grep "cores:" | head -1 | awk '{print $2}'
}

get_current_memory()
{
     docker exec "$CONTAINER" golemsp settings show 2>/dev/null | grep "memory:" | head -1 | awk '{print $2}'
}

log "Demande de passage au profil $LABEL"

if ! inside_window; then
    log "Hors du créneau autorisé. Aucun changement."
    exit 0
fi

CURRENT_CORES=$(get_current_cores)
CURRENT_MEMORY=$(get_current_memory)

if [ "$CURRENT_CORES" = "$CORES" ] && [ "$CURRENT_MEMORY" = "$MEMORY" ]; then
    log "Le profil $LABEL est déjà actif."
    exit 0
fi

while inside_window
do
    JOBS=$(get_active_jobs)

    if [ -z "$JOBS" ]; then
        log "Impossible de déterminer le nombre de jobs actifs. Par sécurité, aucun redémarrage."
        exit 1
    fi

    if [ "$JOBS" = "0" ]; then
        log "Aucun job actif. Passage au profil $LABEL."

         docker exec "$CONTAINER" golemsp settings set --cores "$CORES" --memory "$MEMORY" --disk 20GiB

        if [ $? -ne 0 ]; then
            log "Erreur lors du changement de configuration."
            exit 1
        fi

         docker restart "$CONTAINER"

        if [ $? -ne 0 ]; then
            log "Erreur lors du redémarrage du conteneur."
            exit 1
        fi

        sleep 15

        CURRENT_CORES=$(get_current_cores)
        CURRENT_MEMORY=$(get_current_memory)

        if [ "$CURRENT_CORES" = "$CORES" ] && [ "$CURRENT_MEMORY" = "$MEMORY" ]; then
            log "Profil $LABEL activé avec succès : $CORES CPU / $MEMORY RAM."
            exit 0
        else
            log "ATTENTION : le profil n'a pas pu être vérifié après redémarrage."
            exit 1
        fi
    fi

    log "$JOBS job(s) actif(s). Nouvelle vérification dans 5 minutes."
    sleep "$CHECK_INTERVAL"
done

log "Fin du créneau $LABEL et job toujours actif. Changement annulé jusqu'au prochain créneau."
exit 0