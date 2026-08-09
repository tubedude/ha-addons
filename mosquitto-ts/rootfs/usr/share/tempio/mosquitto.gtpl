user root
{{ if .log_dest }}
# custom log_dest
{{ range .log_dest }}log_dest {{ . }}
{{ end }}
{{ else }}
log_dest stdout
{{ end }}
{{ if .debug }}
log_type all
{{ else if .log_type }}
{{ range .log_type }}log_type {{ . }}
{{ end }}
{{ else }}
log_type error
log_type warning
log_type notice
log_type information
{{ end }}
log_timestamp_format %Y-%m-%d %H:%M:%S
persistence true
persistence_location /data/

# Limits
# max_queued_messages is effectively the upper limit of
# the number of entities on Home Assistant if startup
# is busy and cannot read messages fast enough
max_queued_messages 8192

# Authentication plugin
auth_plugin /usr/share/mosquitto/go-auth.so
# Restore pre-7.0 behaviour: allow '/' in client ids and usernames.
# The addon's ACL file does not use pattern substitution (%c/%u), so
# mosquitto 2.1's broker-side rejection of +, #, / is not needed here.
auth_plugin_deny_special_chars false
auth_opt_backends files,http
auth_opt_hasher pbkdf2
auth_opt_cache true
auth_opt_auth_cache_seconds 300
auth_opt_auth_jitter_seconds 30
auth_opt_acl_cache_seconds 300
auth_opt_acl_jitter_seconds 30
auth_opt_log_level {{ if .debug }}debug{{ else }}error{{ end }}

# Files backend: passwords, and the topic rules that actually bind. Registered
# for user+acl so that ACL decisions have exactly one owner.
auth_opt_files_register user,acl
auth_opt_files_password_path /etc/mosquitto/pw
auth_opt_files_acl_path /etc/mosquitto/acl

# HTTP backend: authentication ONLY.
#
# It used to answer /superuser and /acl as well, and that made per-user ACLs
# impossible. The Supervisor approves the superuser question for every user it
# authenticates, including the local ones from `logins`; a go-auth superuser
# skips ACL checks entirely; and under mosquitto's plugin semantics a native
# acl_file can only widen access, never deny. So every user was unrestricted and
# the ACL recipe in DOCS.md silently did nothing — the debug log said it plainly:
#   superuser bobby_car acl authenticated with backend HTTP
# Registering this backend for `user` alone leaves the files backend to answer
# the ACL question, which is the only place topic rules can take effect.
auth_opt_http_register user
auth_opt_http_host 127.0.0.1
auth_opt_http_port 80
auth_opt_http_getuser_uri /authentication

{{ if .customize }}
include_dir /share/{{ .customize_folder }}
{{ end }}

listener 1883
protocol mqtt

listener 1884
protocol websockets

{{ if .ssl }}

# Follow SSL listener if a certificate exists
listener 8883
protocol mqtt
{{ if .cafile }}
cafile {{ .cafile }}
{{ else }}
cafile {{ .certfile }}
{{ end }}
certfile {{ .certfile }}
keyfile {{ .keyfile }}
require_certificate {{ .require_certificate }}

listener 8884
protocol websockets
{{ if .cafile }}
cafile {{ .cafile }}
{{ else }}
cafile {{ .certfile }}
{{ end }}
certfile {{ .certfile }}
keyfile {{ .keyfile }}
require_certificate {{ .require_certificate }}

{{ end }}
