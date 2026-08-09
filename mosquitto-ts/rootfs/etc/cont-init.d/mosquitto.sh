#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# ==============================================================================
# Configures mosquitto
# ==============================================================================
readonly ACL="/etc/mosquitto/acl"
readonly PW="/etc/mosquitto/pw"
readonly SYSTEM_USER="/data/system_user.json"
declare cafile
declare certfile
declare discovery_password
declare keyfile
declare log_dest
declare log_type
declare password
declare service_password
declare ssl
declare username

# Read or create system account data
if ! bashio::fs.file_exists "${SYSTEM_USER}"; then
  discovery_password="$(pwgen 64 1)"
  service_password="$(pwgen 64 1)"

  # Store it for future use
  bashio::var.json \
    homeassistant "^$(bashio::var.json password "${discovery_password}")" \
    addons "^$(bashio::var.json password "${service_password}")" \
    > "${SYSTEM_USER}"
else
  # Read the existing values
  discovery_password=$(bashio::jq "${SYSTEM_USER}" ".homeassistant.password")
  service_password=$(bashio::jq "${SYSTEM_USER}" ".addons.password")
fi

# Set up discovery user
#
# These two get "topic readwrite #" written out explicitly now. Until 7.2.0 the
# ACL file carried bare "user" lines with no rules at all, and it did not matter
# because the HTTP backend answered /superuser for everyone and no ACL was ever
# consulted. Now that the files backend owns the ACL question, a user with no
# rules is a user with no access — and Home Assistant breaks if these two are
# restricted.
password=$(pw -p "${discovery_password}")
echo "homeassistant:${password}" >> "${PW}"
echo "user homeassistant" >> "${ACL}"
echo "topic readwrite #" >> "${ACL}"

# Set up service user
password=$(pw -p "${service_password}")
echo "addons:${password}" >> "${PW}"
echo "user addons" >> "${ACL}"
echo "topic readwrite #" >> "${ACL}"

# Set username and password for the broker
for login in $(bashio::config 'logins|keys'); do
  bashio::config.require.username "logins[${login}].username"
  bashio::config.require.password "logins[${login}].password"

  username=$(bashio::config "logins[${login}].username")
  password=$(bashio::config "logins[${login}].password")

  bashio::log.info "Setting up user ${username}"
  if ! bashio::config.true "logins[${login}].password_pre_hashed"
  then
      password=$(pw -p "${password}")
  else
      bashio::log.info "Using pre-hashed password for ${username}"
  fi
  echo "${username}:${password}" >> "${PW}"
  echo "user ${username}" >> "${ACL}"

  # Topic rules for this user. Leaving `acl` out keeps the user unrestricted,
  # which is what every configuration written before 7.2.0 expects — adding the
  # list is what opts a user in to being restricted. Each entry is the part of a
  # mosquitto ACL line after the "topic" keyword, e.g.
  #   acl:
  #     - readwrite bobby/geely/#
  #     - write homeassistant/+/bobby_geely/+/config
  if bashio::config.exists "logins[${login}].acl"; then
    for rule in $(bashio::config "logins[${login}].acl|keys"); do
      bashio::log.info "  acl: $(bashio::config "logins[${login}].acl[${rule}]")"
      echo "topic $(bashio::config "logins[${login}].acl[${rule}]")" >> "${ACL}"
    done
  else
    echo "topic readwrite #" >> "${ACL}"
  fi
done

keyfile="/ssl/$(bashio::config 'keyfile')"
certfile="/ssl/$(bashio::config 'certfile')"
cafile="/ssl/$(bashio::config 'cafile')"
if bashio::fs.file_exists "${certfile}" \
  && bashio::fs.file_exists "${keyfile}";
then
  bashio::log.info "Certificates found: SSL is available"
  ssl="true"
  if ! bashio::fs.file_exists "${cafile}"; then
    cafile="${certfile}"
  fi
else
  bashio::log.info "SSL is not enabled"
  ssl="false"
fi

# Get log options as raw JSON types for tempio
options=$(bashio::addon.config)
log_dest=$(jq -c ".log_dest" <<<"$options")
log_type=$(jq -c ".log_type" <<<"$options")

# Generate mosquitto configuration.
bashio::var.json \
  cafile "${cafile}" \
  certfile "${certfile}" \
  customize "^$(bashio::config 'customize.active')" \
  customize_folder "$(bashio::config 'customize.folder')" \
  keyfile "${keyfile}" \
  log_dest "^${log_dest}" \
  log_type "^${log_type}" \
  require_certificate "^$(bashio::config 'require_certificate')" \
  ssl "^${ssl}" \
  debug "^$(bashio::config 'debug')" \
  | tempio \
    -template /usr/share/tempio/mosquitto.gtpl \
    -out /etc/mosquitto/mosquitto.conf
