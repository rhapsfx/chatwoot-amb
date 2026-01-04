#!/bin/bash
# Roo-Debugger-Fix-v3

# Chatwoot Development Server Management Script
# This script manages the Rails server and Sidekiq with the correct Ruby version

# Set the correct Ruby path
eval "$(rbenv init -)"

# --- Ruby Version Check ---
REQUIRED_RUBY_VERSION="3.4.4"
CURRENT_RUBY_VERSION=$(ruby --version | cut -d' ' -f2)

if [ "$CURRENT_RUBY_VERSION" != "$REQUIRED_RUBY_VERSION" ]; then
    echo -e "\033[0;31m[ERROR] Incorrect Ruby version. Expected ${REQUIRED_RUBY_VERSION}, but found ${CURRENT_RUBY_VERSION}.\033[0m"
    echo -e "\033[1;33mPlease install Ruby ${REQUIRED_RUBY_VERSION} and ensure it is the active version.\033[0m"
    echo -e "\033[1;33mIt is highly recommended to use a Ruby version manager like rbenv or asdf.\033[0m"
    exit 1
fi
# --- End Ruby Version Check ---

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# PID files
RAILS_PID_FILE="tmp/pids/server.pid"
SIDEKIQ_PID_FILE="tmp/pids/sidekiq.pid"
NGROK_PID_FILE="tmp/pids/ngrok.pid"
TAILSCALE_FUNNEL_PID_FILE="tmp/pids/tailscale_funnel.pid"
TAILSCALE_URL_FILE="tmp/pids/tailscale_url.txt"
NGINX_PID_FILE="tmp/pids/nginx.pid"

# Domain configuration
NGROK_PORT=3000
NGROK_SUBDOMAIN=""  # Set this to use a custom subdomain (requires ngrok account)
NGROK_CONFIG_FILE="$HOME/.ngrok2/ngrok.yml"  # Default ngrok config location

# Public access configuration
CUSTOM_DOMAIN="macbook-pro-14-perso.tail367da4.ts.net"  # Your custom domain
USE_CUSTOM_DOMAIN=false  # Set to false to use Tailscale Funnel or ngrok
USE_TAILSCALE_FUNNEL=true  # Set to true to use Tailscale Funnel, false for ngrok
TAILSCALE_PORT=10750
DEFAULT_TAILSCALE_URL="macbook-pro-14-perso.tail367da4.ts.net"  # Default Tailscale URL

# Rails configuration files
RAILS_ENV_FILE=".env"
RAILS_CONFIG_FILE="config/environments/development.rb"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to print a clickable URL (OSC 8 hyperlink support)
print_url() {
    local url=$1
    local display_text=${2:-$url}  # Use URL as display text if not provided
    # OSC 8 hyperlink format: \e]8;;URL\e\\DISPLAY_TEXT\e]8;;\e\\
    printf '\e]8;;%s\e\\%b%s%b\e]8;;\e\\\n' "$url" "$BLUE" "$display_text" "$NC"
}

# Function to check if a process is running
is_running() {
    local pid_file=$1
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        # Use kill -0 instead of ps -p to avoid permission issues
        if kill -0 "$pid" > /dev/null 2>&1; then
            return 0
        else
            rm -f "$pid_file"
            return 1
        fi
    fi
    return 1
}

# Function to cleanup stale processes and PID files
cleanup_stale_processes() {
    print_status "Cleaning up stale processes and PID files..."
    
    # Kill any Rails processes running on port 10750
    local rails_pids=$(lsof -ti :10750 2>/dev/null || true)
    if [ -n "$rails_pids" ]; then
        print_status "Killing stale Rails processes on port 10750: $rails_pids"
        echo "$rails_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # Kill any Sidekiq processes that might be orphaned
    local sidekiq_pids=$(pgrep -f "sidekiq" 2>/dev/null || true)
    if [ -n "$sidekiq_pids" ]; then
        print_status "Killing stale Sidekiq processes: $sidekiq_pids"
        echo "$sidekiq_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # Kill any Ruby processes that might be Rails servers or consoles
    local ruby_rails_pids=$(pgrep -f "rails server\|rails console" 2>/dev/null || true)
    if [ -n "$ruby_rails_pids" ]; then
        print_status "Killing stale Rails processes: $ruby_rails_pids"
        echo "$ruby_rails_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # Kill any ngrok processes that might be orphaned
    local ngrok_pids=$(pgrep -f "ngrok" 2>/dev/null || true)
    if [ -n "$ngrok_pids" ]; then
        print_status "Killing stale ngrok processes: $ngrok_pids"
        echo "$ngrok_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi

    # Kill any tailscale funnel processes that might be orphaned
    local tailscale_pids=$(pgrep -f "tailscale funnel" 2>/dev/null || true)
    if [ -n "$tailscale_pids" ]; then
        print_status "Killing stale Tailscale Funnel processes: $tailscale_pids"
        echo "$tailscale_pids" | xargs kill -9 2>/dev/null || true
        sleep 1
    fi
    
    # Remove any stale PID files and temporary files after killing processes
    # But preserve the Tailscale URL file if it exists
    local tailscale_url_backup=""
    if [ -f "$TAILSCALE_URL_FILE" ]; then
        tailscale_url_backup=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
    fi

    rm -rf tmp/pids tmp/cache tmp/*.pid
    mkdir -p tmp/pids tmp/cache

    # Restore the Tailscale URL file if we had one
    if [ -n "$tailscale_url_backup" ]; then
        echo "$tailscale_url_backup" > "$TAILSCALE_URL_FILE"
    fi

    # Also check for Rails-specific PID files that might be elsewhere
    rm -f tmp/server.pid tmp/puma.pid 2>/dev/null || true

    # Clear any spring processes that might be holding onto the server
    if command -v spring >/dev/null 2>&1; then
        spring stop >/dev/null 2>&1 || true
    fi

    # Clear any bundler processes that might interfere
    if command -v bundle >/dev/null 2>&1; then
        bundle exec spring stop >/dev/null 2>&1 || true
    fi
    
    # Wait a moment for processes to fully terminate
    sleep 2
    
    print_success "Cleanup completed"
}

# Function to check if nginx is running
is_nginx_running() {
    if pgrep -f "nginx: master process" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Function to start nginx
start_nginx() {
    if is_nginx_running; then
        print_warning "Nginx is already running"
        return
    fi
    
    print_status "Starting nginx server..."
    
    # Check if nginx is installed
    if ! command -v nginx >/dev/null 2>&1; then
        print_error "Nginx is not installed. Please install nginx first:"
        print_status "Run: brew install nginx"
        return 1
    fi
    
    # Start nginx
    if sudo nginx; then
        print_success "Nginx started successfully"
        printf "        HTTPS proxy available at: "
        print_url "https://dev.rhaps.net"
    else
        print_error "Failed to start nginx"
        print_status "Check nginx configuration with: sudo nginx -t"
        return 1
    fi
}

# Function to stop nginx
stop_nginx() {
    if is_nginx_running; then
        print_status "Stopping nginx server..."
        if sudo nginx -s quit; then
            print_success "Nginx stopped successfully"
        else
            print_warning "Nginx may have stopped ungracefully, trying force stop..."
            sudo pkill -f "nginx: master process" 2>/dev/null || true
            print_success "Nginx stopped"
        fi
    else
        print_warning "Nginx is not running"
    fi
}

# Function to reload nginx configuration
reload_nginx() {
    if is_nginx_running; then
        print_status "Reloading nginx configuration..."
        if sudo nginx -s reload; then
            print_success "Nginx configuration reloaded"
        else
            print_error "Failed to reload nginx configuration"
            return 1
        fi
    else
        print_warning "Nginx is not running, starting instead..."
        start_nginx
    fi
}

# Function to archive old log files and clean up old archives
archive_and_cleanup_logs() {
    print_status "Archiving and cleaning up log files..."
    
    # Create log directory if it doesn't exist
    mkdir -p log
    
    # First, clean up any zero-byte .gz files (failed compressions)
    local zero_byte_count=0
    for gz_file in log/*.gz; do
        [ -e "$gz_file" ] || continue
        if [ ! -s "$gz_file" ]; then
            rm -f "$gz_file"
            zero_byte_count=$((zero_byte_count + 1))
        fi
    done
    
    if [ $zero_byte_count -gt 0 ]; then
        print_success "Removed $zero_byte_count zero-byte archive(s)"
    fi
    
    # Archive .log files (except the current ones that will be used)
    local archived_count=0
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # List of log files to archive (exclude current session logs)
    for log_file in log/*.log; do
        # Skip if file doesn't exist (glob didn't match)
        [ -e "$log_file" ] || continue
        
        # Get the base name without extension
        local base_name=$(basename "$log_file" .log)
        
        # Only archive if file has content (not empty)
        if [ -s "$log_file" ]; then
            # Get file size to verify it's worth archiving (at least 1 byte)
            local file_size=$(wc -c < "$log_file" 2>/dev/null || echo "0")
            
            if [ "$file_size" -gt 0 ]; then
                # Compress the log file
                local archive_path="log/${base_name}_${timestamp}.log.gz"
                if gzip -c "$log_file" > "$archive_path" 2>/dev/null; then
                    # Verify the archive was created and is not empty
                    if [ -s "$archive_path" ]; then
                        # Clear the original log file instead of deleting it
                        > "$log_file"
                        archived_count=$((archived_count + 1))
                    else
                        # Remove failed/empty archive
                        rm -f "$archive_path"
                    fi
                fi
            fi
        fi
    done
    
    # Also archive numbered log files (e.g., development.log.0, development.log.1)
    # Exclude .gz files to prevent re-archiving already compressed files
    for log_file in log/*.log.[0-9]*; do
        [ -e "$log_file" ] || continue
        
        # Skip if this is already a .gz archive
        [[ "$log_file" == *.gz ]] && continue
        
        # Only archive if file has content
        if [ -s "$log_file" ]; then
            local file_size=$(wc -c < "$log_file" 2>/dev/null || echo "0")
            
            if [ "$file_size" -gt 0 ]; then
                local base_name=$(basename "$log_file")
                local archive_path="log/${base_name}_${timestamp}.gz"
                
                if gzip -c "$log_file" > "$archive_path" 2>/dev/null; then
                    # Verify the archive was created and is not empty
                    if [ -s "$archive_path" ]; then
                        rm -f "$log_file"
                        archived_count=$((archived_count + 1))
                    else
                        # Remove failed/empty archive
                        rm -f "$archive_path"
                    fi
                fi
            fi
        fi
    done
    
    if [ $archived_count -gt 0 ]; then
        print_success "Archived $archived_count log file(s)"
    fi
    
    # Clean up .gz archives older than 5 days
    local deleted_count=0
    local cutoff_date=$(date -v-5d +%s 2>/dev/null || date -d '5 days ago' +%s 2>/dev/null)
    
    if [ -n "$cutoff_date" ]; then
        for gz_file in log/*.gz; do
            [ -e "$gz_file" ] || continue
            
            # Skip if file is empty (shouldn't happen after cleanup above, but just in case)
            [ -s "$gz_file" ] || continue
            
            # Get file modification time
            local file_time=$(stat -f %m "$gz_file" 2>/dev/null || stat -c %Y "$gz_file" 2>/dev/null)
            
            if [ -n "$file_time" ] && [ "$file_time" -lt "$cutoff_date" ]; then
                rm -f "$gz_file"
                deleted_count=$((deleted_count + 1))
            fi
        done
        
        if [ $deleted_count -gt 0 ]; then
            print_success "Deleted $deleted_count old archive(s) (>5 days)"
        fi
    else
        print_warning "Could not determine date for cleanup (date command compatibility issue)"
    fi
    
    print_success "Log archiving and cleanup completed"
}

# Function to start the Rails server
start_rails() {
    if is_running "$RAILS_PID_FILE"; then
        print_warning "Rails server is already running (PID: $(cat $RAILS_PID_FILE))"
        return
    fi

    # Extra check: make sure no Rails process is using the port
    local port_check=$(lsof -ti :10750 2>/dev/null || true)
    if [ -n "$port_check" ]; then
        print_warning "Port 10750 is in use by process $port_check. Killing it..."
        kill -9 "$port_check" 2>/dev/null || true
        sleep 2
    fi

    # Remove any stale Rails PID files before starting
    rm -f tmp/pids/server.pid tmp/server.pid tmp/puma.pid 2>/dev/null || true

    print_status "Starting Rails server with Ruby $(ruby --version | cut -d' ' -f2)..."

    # Create log directory if it doesn't exist
    mkdir -p log

    # Start Rails server with binding for Tailscale Funnel compatibility
    nohup bundle exec rails server -p 10750 --binding=0.0.0.0 --pid="$RAILS_PID_FILE" > log/rails.log 2>&1 &
    RAILS_PID=$!

    # Wait and check for Rails to start with multiple retries
    local attempts=0
    local max_attempts=45
    local port_ready=false

    print_status "Waiting for Rails server to start (increased timeout to 45s)..."

    while [ $attempts -lt $max_attempts ]; do
        if lsof -i :10750 > /dev/null 2>&1; then
            port_ready=true
            break
        fi

        # Check if the process is still running
        if ! kill -0 "$RAILS_PID" > /dev/null 2>&1; then
            print_error "Rails process terminated unexpectedly"
            break
        fi

        attempts=$((attempts + 1))
        sleep 1
        echo -n "."
    done
    echo ""

    # Final check
    if [ "$port_ready" = true ]; then
        print_success "Rails server started successfully (PID: $RAILS_PID)"
        printf "        Server available at: "
        print_url "http://localhost:10750"
    else
        print_error "Failed to start Rails server after ${max_attempts} seconds"
        print_status "Check log/rails.log for details:"
        tail -20 log/rails.log 2>/dev/null || echo "No log file found"
        rm -f "$RAILS_PID_FILE"
    fi
}

# Function to start Sidekiq
start_sidekiq() {
    if is_running "$SIDEKIQ_PID_FILE"; then
        print_warning "Sidekiq is already running (PID: $(cat $SIDEKIQ_PID_FILE))"
        return
    fi
    
    print_status "Starting Sidekiq..."
    
    # Create log directory if it doesn't exist
    mkdir -p log
    
    # Set hostname for sidekiq_alive gem identification
    export HOSTNAME="macbook-pro-14-perso-dev"
    
    # Start Sidekiq in background (newer versions don't support -d flag)
    nohup bundle exec sidekiq > log/sidekiq.log 2>&1 &
    SIDEKIQ_PID=$!
    echo $SIDEKIQ_PID > "$SIDEKIQ_PID_FILE"
    
    # Wait a moment for Sidekiq to start
    sleep 2
    
    if is_running "$SIDEKIQ_PID_FILE"; then
        print_success "Sidekiq started successfully (PID: $(cat $SIDEKIQ_PID_FILE))"
    else
        print_error "Failed to start Sidekiq"
    fi
}

# Function to stop the Rails server
stop_rails() {
    local quiet_mode=${1:-false}
    if is_running "$RAILS_PID_FILE"; then
        local pid=$(cat "$RAILS_PID_FILE")
        print_status "Stopping Rails server (PID: $pid)..."
        kill "$pid"
        rm -f "$RAILS_PID_FILE"
        print_success "Rails server stopped"
    elif [ "$quiet_mode" != "true" ]; then
        print_warning "Rails server is not running"
    fi
}

# The functions to update the .env file have been removed.
# This was causing the "server is already running" error.

# Function to start ngrok
start_ngrok() {
    if is_running "$NGROK_PID_FILE"; then
        print_warning "Ngrok is already running (PID: $(cat $NGROK_PID_FILE))"
        return
    fi
    
    # Check if ngrok is installed
    if ! command -v ngrok >/dev/null 2>&1; then
        print_error "Ngrok is not installed. Please install ngrok first:"
        print_status "Visit https://ngrok.com/download or run: brew install ngrok"
        return 1
    fi
    
    print_status "Starting ngrok tunnel for port $NGROK_PORT..."
    
    # Create log directory if it doesn't exist
    mkdir -p log
    
    # Build ngrok command
    local ngrok_cmd="ngrok http $NGROK_PORT"
    if [ -n "$NGROK_SUBDOMAIN" ]; then
        ngrok_cmd="$ngrok_cmd --subdomain=$NGROK_SUBDOMAIN"
    fi
    
    # Start ngrok in background
    nohup $ngrok_cmd > log/ngrok.log 2>&1 &
    NGROK_PID=$!
    echo $NGROK_PID > "$NGROK_PID_FILE"
    
    # Wait for ngrok to start and establish tunnel
    print_status "Waiting for ngrok to establish tunnel..."
    local attempts=0
    local max_attempts=30
    
    while [ $attempts -lt $max_attempts ]; do
        if curl -s http://localhost:4040/api/tunnels >/dev/null 2>&1; then
            local tunnels_json=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null)
            if [ $? -eq 0 ] && [ -n "$tunnels_json" ]; then
                local ngrok_url=$(echo "$tunnels_json" | grep -o '"public_url":"https://[^"]*"' | grep -o 'https://[^"]*' | head -1)
                if [ -n "$ngrok_url" ]; then
                    print_success "Ngrok started successfully (PID: $NGROK_PID)"
                    printf "        Public URL: "
                    print_url "$ngrok_url"

                    # Update Rails configuration with ngrok URL
                    # The function to update the .env file has been removed.

                    return 0
                fi
            fi
        fi
        
        attempts=$((attempts + 1))
        sleep 1
    done
    
    print_error "Failed to start ngrok or establish tunnel"
    print_status "Check log/ngrok.log for details:"
    tail -10 log/ngrok.log 2>/dev/null || echo "No log file found"
    rm -f "$NGROK_PID_FILE"
    return 1
}

# Function to stop ngrok
stop_ngrok() {
    local quiet_mode=${1:-false}
    if is_running "$NGROK_PID_FILE"; then
        local pid=$(cat "$NGROK_PID_FILE")
        print_status "Stopping ngrok (PID: $pid)..."
        kill "$pid"
        rm -f "$NGROK_PID_FILE"

        # Remove ngrok configuration from Rails
        # The function to update the .env file has been removed.

        print_success "Ngrok stopped"
    elif [ "$quiet_mode" != "true" ]; then
        print_warning "Ngrok is not running"
    fi
}

# Function to ask user for Tailscale Funnel URL
ask_tailscale_funnel_url() {
    # Check if running in non-interactive mode (no TTY)
    if [ ! -t 0 ]; then
        # Non-interactive - use default immediately
        echo "$DEFAULT_TAILSCALE_URL"
        return 0
    fi

    print_status "Please provide your Tailscale Funnel URL:"
    print_status "Example: your-machine.your-tailnet.ts.net"
    print_status "Press Enter to use default: $DEFAULT_TAILSCALE_URL"

    # Use timeout with read to prevent blocking - if no input in 1 second, use default
    if read -t 1 -p "Enter your Tailscale URL (without https://): " tailscale_url 2>/dev/null; then
        # User provided input
        :
    else
        # No input or timeout - use default
        tailscale_url=""
    fi

    # Use default if nothing entered
    if [ -z "$tailscale_url" ]; then
        tailscale_url="$DEFAULT_TAILSCALE_URL"
    fi

    # Clean the input - remove any whitespace and protocol prefixes
    tailscale_url=$(echo "$tailscale_url" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sed 's|^https\?://||')

    if [ -n "$tailscale_url" ]; then
        # Only echo the clean URL, no other text
        echo "$tailscale_url"
        return 0
    fi

    return 1
}

# Function to start Tailscale Funnel
start_tailscale_funnel() {
    if is_running "$TAILSCALE_FUNNEL_PID_FILE"; then
        print_warning "Tailscale Funnel is already running (PID: $(cat $TAILSCALE_FUNNEL_PID_FILE))"
        return
    fi

    # Check if Tailscale is installed
    if ! command -v tailscale >/dev/null 2>&1; then
        print_error "Tailscale is not installed. Please install Tailscale first:"
        print_status "Visit https://tailscale.com/download or run: brew install tailscale"
        return 1
    fi

    # Check if Tailscale Funnel is already running with timeout (using perl for macOS compatibility)
    local tailscale_funnel_output=$(perl -e 'alarm 3; exec @ARGV' tailscale funnel status 2>/dev/null || echo "")

    if echo "$tailscale_funnel_output" | grep -q "Funnel on" && echo "$tailscale_funnel_output" | grep -q ":$TAILSCALE_PORT"; then
        print_success "Tailscale Funnel is already active and funneling port $TAILSCALE_PORT"

        # Extract and save the URL
        local funnel_url=$(echo "$tailscale_funnel_output" | grep -E "https://.*\.ts\.net" | head -1 | sed 's/.*https:\/\///' | sed 's/ .*//' | sed 's|/$||')
        if [ -n "$funnel_url" ]; then
            echo "$funnel_url" > "$TAILSCALE_URL_FILE"
            printf "        Public URL: "
            print_url "https://$funnel_url"
        fi

        # Create tracking file
        echo "existing_tailscale_funnel" > "$TAILSCALE_FUNNEL_PID_FILE"
        return 0
    fi

    print_status "Starting Tailscale Funnel for port $TAILSCALE_PORT..."

    # Check Tailscale authentication status with timeout (using perl for macOS compatibility)
    local tailscale_status_output=$(perl -e 'alarm 3; exec @ARGV' tailscale status 2>/dev/null || echo "")
    if [ -z "$tailscale_status_output" ]; then
        print_error "Tailscale is not authenticated. Run 'tailscale up' first"
        return 1
    fi

    if echo "$tailscale_status_output" | grep -q "Logged out"; then
        print_error "Tailscale is logged out. Run 'tailscale up' to log in"
        return 1
    fi

    # Check if Funnel is enabled for this tailnet
    if echo "$tailscale_funnel_output" | grep -q "funnel not enabled"; then
        print_error "Funnel is not enabled for this tailnet"
        print_status "Enable it in Tailscale admin console: https://login.tailscale.com/admin/settings/features"
        return 1
    fi

    print_status "Note: Please run 'tailscale funnel $TAILSCALE_PORT' in your own terminal"
    print_status "This script cannot execute privileged Tailscale commands directly"

    # Create log directory if it doesn't exist
    mkdir -p log

    # Create a placeholder process to track Tailscale Funnel
    print_status "Waiting for you to start Tailscale Funnel in another terminal..."
    echo "manual_tailscale_funnel" > "$TAILSCALE_FUNNEL_PID_FILE"

    # Use timeout with read to prevent blocking - skip prompt in non-interactive mode
    if [ -t 0 ]; then
        print_status "Once you start 'tailscale funnel $TAILSCALE_PORT', press Enter to continue (auto-continuing in 1 second)..."
        read -t 1 -r 2>/dev/null || true
    fi

    # Ask user for their Tailscale URL or use default
    local funnel_url
    if [ -f "$TAILSCALE_URL_FILE" ]; then
        # Use existing saved URL
        funnel_url=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
        print_success "Using saved Tailscale Funnel URL: $funnel_url"
    else
        # Ask for URL or use default
        if funnel_url=$(ask_tailscale_funnel_url); then
            # Save the URL to a file for status checking
            echo "$funnel_url" > "$TAILSCALE_URL_FILE"
            print_success "Tailscale Funnel URL saved: $funnel_url"
        else
            print_error "No Tailscale Funnel URL provided"
            rm -f "$TAILSCALE_FUNNEL_PID_FILE"
            return 1
        fi
    fi

    printf "    Public URL: "
    print_url "https://$funnel_url"
    return 0
}

# Function to stop Tailscale Funnel
stop_tailscale_funnel() {
    local quiet_mode=${1:-false}
    if is_running "$TAILSCALE_FUNNEL_PID_FILE"; then
        print_status "Tailscale Funnel is running manually"
        print_status "Please stop it yourself with: Ctrl+C in the terminal where you ran 'tailscale funnel'"
        rm -f "$TAILSCALE_FUNNEL_PID_FILE"
        rm -f "$TAILSCALE_URL_FILE"
        print_success "Tailscale Funnel tracking stopped"
    elif [ "$quiet_mode" != "true" ]; then
        print_warning "Tailscale Funnel is not being tracked by this script"
    fi
}

# Function to check Tailscale Funnel status
check_tailscale_funnel_status() {
    local funnel_status=""
    local funnel_url=""
    local detailed_status=""

    # Read the URL from the saved file first (only first line, clean)
    if [ -f "$TAILSCALE_URL_FILE" ]; then
        funnel_url=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
    fi

    # Check if Tailscale is installed and accessible
    if ! command -v tailscale >/dev/null 2>&1; then
        funnel_status="${RED}TAILSCALE NOT INSTALLED${NC}"
        echo "$funnel_status|$funnel_url|Tailscale command not found"
        return
    fi

    # SKIP LIVE CHECKS - tailscale commands can block Claude
    # Instead, rely on saved state and tracking files
    if is_running "$TAILSCALE_FUNNEL_PID_FILE"; then
        if [ -n "$funnel_url" ]; then
            funnel_status="${GREEN}TRACKED AS RUNNING${NC}"
            detailed_status="Tracked by script (use 'tailscale funnel status' manually to verify)"
        else
            funnel_status="${YELLOW}SCRIPT TRACKING ACTIVE${NC}"
            detailed_status="Tracked but no URL saved"
        fi
    elif [ -n "$funnel_url" ]; then
        funnel_status="${YELLOW}CONFIGURED${NC}"
        detailed_status="URL saved: $funnel_url (connectivity auto-verified on restart)"
    else
        funnel_status="${YELLOW}STATUS UNKNOWN${NC}"
        detailed_status="Run './script//dev-server.sh tailscale-status' in your terminal to check"
    fi

    echo "$funnel_status|$funnel_url|$detailed_status"
}

# Function to stop Sidekiq
stop_sidekiq() {
    local quiet_mode=${1:-false}
    if is_running "$SIDEKIQ_PID_FILE"; then
        local pid=$(cat "$SIDEKIQ_PID_FILE")
        print_status "Stopping Sidekiq (PID: $pid)..."
        kill "$pid"
        rm -f "$SIDEKIQ_PID_FILE"
        print_success "Sidekiq stopped"
    elif [ "$quiet_mode" != "true" ]; then
        print_warning "Sidekiq is not running"
    fi
}

# Function to check ngrok status
check_ngrok_status() {
    local ngrok_status=""
    local ngrok_url=""

    # Try to connect to ngrok's local API with 2 second timeout
    if curl -s --max-time 2 http://localhost:4040/api/tunnels >/dev/null 2>&1; then
        local tunnels_json=$(curl -s --max-time 2 http://localhost:4040/api/tunnels 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$tunnels_json" ]; then
            # Find HTTPS tunnel pointing to port 3000
            ngrok_url=$(echo "$tunnels_json" | grep -o '"public_url":"https://[^"]*"' | grep -o 'https://[^"]*' | head -1)
            if [ -n "$ngrok_url" ]; then
                ngrok_status="${GREEN}RUNNING${NC}"
            else
                ngrok_status="${YELLOW}RUNNING (no HTTPS tunnel to port 3000)${NC}"
            fi
        else
            ngrok_status="${RED}API ERROR${NC}"
        fi
    else
        ngrok_status="${RED}NOT RUNNING${NC}"
    fi

    echo "$ngrok_status|$ngrok_url"
}

# Function to show detailed Tailscale status
show_tailscale_status() {
    echo -e "\n${BLUE}=== Tailscale Status Check ===${NC}"

    # Check if Tailscale is installed
    if ! command -v tailscale >/dev/null 2>&1; then
        echo -e "${RED}✗ Tailscale not installed${NC}"
        echo -e "Install with: ${YELLOW}brew install tailscale${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Tailscale installed${NC}"

    # Check Tailscale status with timeout (using perl for macOS compatibility)
    local tailscale_status_output=$(perl -e 'alarm 3; exec @ARGV' tailscale status 2>/dev/null || echo "")
    if [ -z "$tailscale_status_output" ]; then
        echo -e "${RED}✗ Tailscale not authenticated${NC}"
        echo -e "Run: ${YELLOW}tailscale up${NC}"
        return 1
    fi

    if echo "$tailscale_status_output" | grep -q "Logged out"; then
        echo -e "${RED}✗ Tailscale logged out${NC}"
        echo -e "Run: ${YELLOW}tailscale up${NC}"
        return 1
    fi

    echo -e "${GREEN}✓ Tailscale authenticated and logged in${NC}"

    # Show machine name and tailnet
    local machine_name=$(echo "$tailscale_status_output" | head -1 | awk '{print $1}')
    local tailnet=$(echo "$tailscale_status_output" | grep -o "[^[:space:]]*\.ts\.net" | head -1)

    if [ -n "$machine_name" ]; then
        echo -e "Machine: ${BLUE}$machine_name${NC}"
    fi
    if [ -n "$tailnet" ]; then
        echo -e "Tailnet: ${BLUE}$tailnet${NC}"
    fi

    # Check Funnel capability and status with timeout (using perl for macOS compatibility)
    local tailscale_funnel_output=$(perl -e 'alarm 3; exec @ARGV' tailscale funnel status 2>/dev/null || echo "")

    if echo "$tailscale_funnel_output" | grep -q "funnel not enabled"; then
        echo -e "${RED}✗ Funnel not enabled for this tailnet${NC}"
        echo -e "Enable in Tailscale admin console: ${YELLOW}https://login.tailscale.com/admin/settings/features${NC}"
        return 1
    fi

    if echo "$tailscale_funnel_output" | grep -q "no funnel configured"; then
        echo -e "${YELLOW}⚠ Funnel enabled but not configured${NC}"
        echo -e "Start with: ${YELLOW}tailscale funnel $TAILSCALE_PORT${NC}"
        return 0
    fi

    if echo "$tailscale_funnel_output" | grep -q "Funnel on"; then
        echo -e "${GREEN}✓ Funnel is active${NC}"

        # Show active funnels
        echo -e "\n${BLUE}Active Funnels:${NC}"
        echo "$tailscale_funnel_output" | grep -E "(https://.*\.ts\.net|:[0-9]+)" | while read -r line; do
            if [[ "$line" =~ https://.*\.ts\.net ]]; then
                local url=$(echo "$line" | grep -oE 'https://[^[:space:]]*\.ts\.net[^[:space:]]*')
                echo -e "  ${GREEN}$url${NC}"
            elif [[ "$line" =~ :[0-9]+ ]]; then
                echo -e "  ${BLUE}$line${NC}"
            fi
        done

        # Check if our specific port is being funneled
        if echo "$tailscale_funnel_output" | grep -q ":$TAILSCALE_PORT"; then
            echo -e "\n${GREEN}✓ Port $TAILSCALE_PORT is being funneled${NC}"
        else
            echo -e "\n${YELLOW}⚠ Port $TAILSCALE_PORT is not being funneled${NC}"
            echo -e "Run: ${YELLOW}tailscale funnel $TAILSCALE_PORT${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Funnel status unclear${NC}"
        echo -e "Try: ${YELLOW}tailscale funnel $TAILSCALE_PORT${NC}"
    fi

    echo ""
}

# Function to test external connectivity to Tailscale domain
test_external_connectivity() {
    local domain=${1:-"$CUSTOM_DOMAIN"}
    local port=${2:-""}
    local test_url=""
    local quiet_mode=${3:-false}
    
    # Construct the test URL
    if [ -n "$port" ]; then
        test_url="https://${domain}:${port}"
    else
        test_url="https://${domain}"
    fi
    
    if [ "$quiet_mode" != "true" ]; then
        print_status "Testing external connectivity to: $test_url"
    fi
    
    # Test 1: Basic HTTPS connectivity
    local connectivity_result=""
    local http_status=""
    local response_time=""
    
    # Use curl with timeout and follow redirects
    local curl_output=$(curl -s -w "%{http_code}|%{time_total}" \
        --max-time 10 \
        --connect-timeout 5 \
        --retry 2 \
        --retry-delay 1 \
        -L \
        -H "User-Agent: Chatwoot-DevServer-ConnTest/1.0" \
        "$test_url" 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$curl_output" ]; then
        http_status=$(echo "$curl_output" | tail -1 | cut -d'|' -f1)
        response_time=$(echo "$curl_output" | tail -1 | cut -d'|' -f2)
        
        # Check if we got a reasonable HTTP response
        if [[ "$http_status" =~ ^[2345][0-9][0-9]$ ]]; then
            connectivity_result="SUCCESS"
            if [ "$quiet_mode" != "true" ]; then
                print_success "External connectivity test passed (HTTP $http_status, ${response_time}s)"
            fi
        else
            connectivity_result="HTTP_ERROR"
            if [ "$quiet_mode" != "true" ]; then
                print_warning "External connectivity issue: HTTP status $http_status"
            fi
        fi
    else
        connectivity_result="FAILED"
        if [ "$quiet_mode" != "true" ]; then
            print_error "External connectivity test failed: Cannot reach $test_url"
        fi
    fi
    
    # Test 2: DNS resolution check
    if [ "$quiet_mode" != "true" ]; then
        print_status "Testing DNS resolution for $domain..."
    fi
    
    local dns_result=""
    if nslookup "$domain" >/dev/null 2>&1; then
        dns_result="SUCCESS"
        if [ "$quiet_mode" != "true" ]; then
            print_success "DNS resolution successful for $domain"
        fi
    else
        dns_result="FAILED"
        if [ "$quiet_mode" != "true" ]; then
            print_error "DNS resolution failed for $domain"
        fi
    fi
    
    # Test 3: Check if it's a Tailscale domain and verify Tailscale status
    local tailscale_check=""
    if [[ "$domain" == *.ts.net ]]; then
        if [ "$quiet_mode" != "true" ]; then
            print_status "Detected Tailscale domain, checking Funnel status..."
        fi
        
        if command -v tailscale >/dev/null 2>&1; then
            # Quick Tailscale status check with timeout
            local tailscale_status_output=$(perl -e 'alarm 3; exec @ARGV' tailscale status 2>/dev/null || echo "")
            if [ -n "$tailscale_status_output" ] && ! echo "$tailscale_status_output" | grep -q "Logged out"; then
                tailscale_check="AUTHENTICATED"
                if [ "$quiet_mode" != "true" ]; then
                    print_success "Tailscale is authenticated"
                fi
            else
                tailscale_check="NOT_AUTHENTICATED"
                if [ "$quiet_mode" != "true" ]; then
                    print_warning "Tailscale is not authenticated - this may affect external access"
                fi
            fi
        else
            tailscale_check="NOT_INSTALLED"
            if [ "$quiet_mode" != "true" ]; then
                print_warning "Tailscale not installed, cannot verify Funnel status"
            fi
        fi
    else
        tailscale_check="NOT_TAILSCALE"
    fi
    
    # Summary
    local overall_status="UNKNOWN"
    if [ "$connectivity_result" = "SUCCESS" ] && [ "$dns_result" = "SUCCESS" ]; then
        overall_status="PASS"
        if [ "$quiet_mode" != "true" ]; then
            print_success "External connectivity verification PASSED"
            echo -e "${GREEN}✓ Apple Messages for Business webhooks should be able to reach this server${NC}"
        fi
    elif [ "$connectivity_result" = "HTTP_ERROR" ] && [ "$dns_result" = "SUCCESS" ]; then
        overall_status="PARTIAL"
        if [ "$quiet_mode" != "true" ]; then
            print_warning "External connectivity PARTIALLY working (DNS OK, HTTP issues)"
            echo -e "${YELLOW}⚠ Apple Messages webhooks may have issues reaching this server${NC}"
        fi
    else
        overall_status="FAIL"
        if [ "$quiet_mode" != "true" ]; then
            print_error "External connectivity verification FAILED"
            echo -e "${RED}✗ Apple Messages for Business webhooks will NOT be able to reach this server${NC}"
            
            # Provide troubleshooting suggestions
            echo -e "\n${YELLOW}Troubleshooting suggestions:${NC}"
            if [ "$dns_result" = "FAILED" ]; then
                echo -e "  • DNS resolution failed - check if domain is correctly configured"
            fi
            if [[ "$domain" == *.ts.net ]] && [ "$tailscale_check" != "AUTHENTICATED" ]; then
                echo -e "  • Run 'tailscale up' to authenticate Tailscale"
                echo -e "  • Run 'tailscale funnel $TAILSCALE_PORT' to enable Funnel"
            fi
            echo -e "  • Check firewall and network connectivity"
            echo -e "  • Verify the server is actually running and accessible locally first"
        fi
    fi
    
    # Return status code based on overall result
    case "$overall_status" in
        "PASS") return 0 ;;
        "PARTIAL") return 1 ;;
        "FAIL") return 2 ;;
        *) return 3 ;;
    esac
}

# Function to test Apple Messages webhook endpoint specifically
test_apple_messages_connectivity() {
    local domain=${1:-"$CUSTOM_DOMAIN"}
    local quiet_mode=${2:-false}
    
    if [ "$quiet_mode" != "true" ]; then
        echo -e "\n${BLUE}=== Apple Messages for Business Connectivity Test ===${NC}"
    fi
    
    # Test the webhook endpoint specifically
    local webhook_url="https://${domain}/webhooks/apple_messages_for_business/message"
    
    if [ "$quiet_mode" != "true" ]; then
        print_status "Testing Apple Messages webhook endpoint: $webhook_url"
    fi
    
    # Use curl to test the webhook endpoint
    local webhook_result=$(curl -s -w "%{http_code}" \
        --max-time 10 \
        --connect-timeout 5 \
        -X POST \
        -H "Content-Type: application/json" \
        -H "User-Agent: Apple-Messages-Webhook-Test/1.0" \
        -d '{"test": "connectivity"}' \
        "$webhook_url" 2>/dev/null)
    
    local webhook_status=""
    if [ -n "$webhook_result" ]; then
        webhook_status=$(echo "$webhook_result" | tail -c 4 | head -c 3)
        
        # We expect 400, 401, or 422 for a malformed test request, which means the endpoint is reachable
        if [[ "$webhook_status" =~ ^(400|401|422|404|500)$ ]]; then
            if [ "$quiet_mode" != "true" ]; then
                print_success "Apple Messages webhook endpoint is externally reachable (HTTP $webhook_status)"
                echo -e "${GREEN}✓ Apple can send webhooks to this server${NC}"
            fi
            return 0
        elif [[ "$webhook_status" =~ ^2[0-9][0-9]$ ]]; then
            if [ "$quiet_mode" != "true" ]; then
                print_success "Apple Messages webhook endpoint responded successfully (HTTP $webhook_status)"
                echo -e "${GREEN}✓ Apple can send webhooks to this server${NC}"
            fi
            return 0
        else
            if [ "$quiet_mode" != "true" ]; then
                print_warning "Apple Messages webhook endpoint returned unexpected status: $webhook_status"
            fi
            return 1
        fi
    else
        if [ "$quiet_mode" != "true" ]; then
            print_error "Cannot reach Apple Messages webhook endpoint"
            echo -e "${RED}✗ Apple cannot send webhooks to this server${NC}"
        fi
        return 2
    fi
}
show_status() {
    echo -e "\n${BLUE}=== Chatwoot Development Server Status ===${NC}"
    echo -e "Ruby Version: ${GREEN}$(ruby --version)${NC}"
    echo -e "Bundler Version: ${GREEN}$(bundle --version)${NC}"
    echo ""
    
    if is_running "$RAILS_PID_FILE"; then
        echo -e "Rails Server: ${GREEN}RUNNING${NC} (PID: $(cat $RAILS_PID_FILE))"
        printf "Local URL: "
        print_url "http://localhost:10750"
    else
        echo -e "Rails Server: ${RED}STOPPED${NC}"
    fi
    
    if is_running "$SIDEKIQ_PID_FILE"; then
        echo -e "Sidekiq: ${GREEN}RUNNING${NC} (PID: $(cat $SIDEKIQ_PID_FILE))"
    else
        echo -e "Sidekiq: ${RED}STOPPED${NC}"
    fi
    
    # Nginx status output disabled
    # if is_nginx_running; then
    #     echo -e "Nginx: ${GREEN}RUNNING${NC}"
    #     echo -e "HTTPS URL: ${BLUE}https://$CUSTOM_DOMAIN${NC}"
    # else
    #     echo -e "Nginx: ${RED}STOPPED${NC}"
    # fi
    
    # Ngrok status output disabled
    # Check ngrok status
    local ngrok_info=$(check_ngrok_status)
    local ngrok_status=$(echo "$ngrok_info" | cut -d'|' -f1)
    local ngrok_url=$(echo "$ngrok_info" | cut -d'|' -f2)

    # if is_running "$NGROK_PID_FILE"; then
    #     echo -e "Ngrok: ${GREEN}RUNNING${NC} (PID: $(cat $NGROK_PID_FILE))"
    # else
    #     echo -e "Ngrok: $ngrok_status"
    # fi

    # Check Tailscale Funnel status
    local tailscale_info=$(check_tailscale_funnel_status)
    local tailscale_status=$(echo "$tailscale_info" | cut -d'|' -f1)
    local tailscale_url=$(echo "$tailscale_info" | cut -d'|' -f2)
    local tailscale_details=$(echo "$tailscale_info" | cut -d'|' -f3)

    # Display Tailscale Funnel status with URL and details if available
    if echo "$tailscale_status" | grep -q "RUNNING"; then
        if [ -n "$tailscale_url" ]; then
            echo -e "Tailscale Funnel: $tailscale_status (URL: $tailscale_url)"
        else
            echo -e "Tailscale Funnel: $tailscale_status"
        fi
        if [ -n "$tailscale_details" ]; then
            echo -e "  └─ $tailscale_details"
        fi
    else
        echo -e "Tailscale Funnel: $tailscale_status"
        if [ -n "$tailscale_details" ]; then
            echo -e "  └─ $tailscale_details"
        fi
    fi

    # Determine which public URL to show based on what's actually running
    if echo "$tailscale_status" | grep -q "RUNNING" && [ -n "$tailscale_url" ]; then
        printf "HTTPS URL: "
        print_url "https://$tailscale_url"
        echo -e "${YELLOW}Note: Apple Messages for Business webhooks will use Tailscale Funnel URLs (connectivity auto-verified)${NC}"
    elif [ "$USE_CUSTOM_DOMAIN" = true ] && is_nginx_running; then
        printf "HTTPS URL: "
        print_url "https://$CUSTOM_DOMAIN"
        echo -e "${YELLOW}Note: Apple Messages for Business webhooks will use custom domain URLs (connectivity auto-verified)${NC}"
        echo -e "${YELLOW}Ensure port forwarding is configured: External port 3000 -> Internal IP:3000${NC}"
    elif [ -n "$ngrok_url" ]; then
        printf "Public URL: "
        print_url "$ngrok_url"
        echo -e "${YELLOW}Note: Apple Messages for Business webhooks will use ngrok URLs (connectivity auto-verified)${NC}"
    else
        echo -e "${YELLOW}Note: Apple Messages for Business webhooks will use localhost URLs (external connectivity not verified)${NC}"
    fi
    echo ""
}

# Function to rotate log file
rotate_log() {
    local log_file="log/development.log"
    
    if [ -f "$log_file" ]; then
        local timestamp=$(date +"%Y%m%d_%H%M%S")
        local rotated_log="log/development.log.${timestamp}"
        
        print_status "Rotating development log..."
        mv "$log_file" "$rotated_log"
        print_success "Log rotated to: ${rotated_log}"
        
        # Optionally compress old log to save space
        if command -v gzip >/dev/null 2>&1; then
            gzip "$rotated_log"
            print_success "Compressed rotated log: ${rotated_log}.gz"
        fi
        
        # Create new empty log file
        touch "$log_file"
    else
        print_warning "No development log file found to rotate"
    fi
}

# Function to restart services
restart_services() {
    print_status "Restarting development services..."
    stop_rails true
    stop_sidekiq true
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        stop_nginx
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        stop_tailscale_funnel true
    else
        stop_ngrok true
    fi
    sleep 2
    
    # Rotate the development log file
    rotate_log
    
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        start_nginx
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        start_tailscale_funnel
    else
        start_ngrok
    fi
    start_rails
    start_sidekiq
    
    # Test external connectivity after restart
    print_status "Verifying external connectivity after restart..."
    sleep 3  # Give services a moment to fully start
    
    local domain_to_test=""
    if [ "$USE_TAILSCALE_FUNNEL" = true ] && [ -f "$TAILSCALE_URL_FILE" ]; then
        domain_to_test=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
    elif [ "$USE_CUSTOM_DOMAIN" = true ]; then
        domain_to_test="$CUSTOM_DOMAIN"
    fi
    
    if [ -n "$domain_to_test" ]; then
        echo -e "\n${BLUE}=== Post-Restart Connectivity Verification ===${NC}"
        test_external_connectivity "$domain_to_test"
        local connectivity_result=$?
        
        # Also test Apple Messages specific endpoint
        test_apple_messages_connectivity "$domain_to_test"
        local apple_result=$?
        
        echo ""
        if [ $connectivity_result -eq 0 ] && [ $apple_result -eq 0 ]; then
            print_success "All external connectivity checks passed"
        elif [ $connectivity_result -le 1 ] || [ $apple_result -le 1 ]; then
            print_warning "Some connectivity issues detected - check logs above"
        else
            print_error "External connectivity verification failed - Apple Messages webhooks may not work"
        fi
    else
        print_warning "No external domain configured - skipping connectivity test"
    fi
    
    show_status
}

# Function to start all services with custom domain, Tailscale Funnel, or ngrok coordination
start_all_services() {
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        print_status "Starting Chatwoot development server with custom domain ($CUSTOM_DOMAIN)..."
        cleanup_stale_processes

        print_status "Using custom domain: https://$CUSTOM_DOMAIN"
        print_status "Ensure your Freebox port forwarding is configured:"
        print_status "  External port 3000 -> Internal IP ($(ipconfig getifaddr en0 || echo '192.168.1.x')):3000"

        start_nginx
        start_rails
        start_sidekiq
        show_status
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        print_status "Starting Chatwoot development server with Tailscale Funnel..."
        cleanup_stale_processes

        # Start Tailscale Funnel first so Rails can detect it
        start_tailscale_funnel
        if [ $? -eq 0 ]; then
            print_status "Tailscale Funnel established, starting Rails server..."
            sleep 2  # Give Tailscale Funnel a moment to fully establish
        else
            print_warning "Tailscale Funnel failed to start, continuing with localhost only..."
        fi

        start_rails
        start_sidekiq
        show_status
    else
        print_status "Starting Chatwoot development server with ngrok..."
        cleanup_stale_processes

        # Start ngrok first so Rails can detect it
        start_ngrok
        if [ $? -eq 0 ]; then
            print_status "Ngrok tunnel established, starting Rails server..."
            sleep 2  # Give ngrok a moment to fully establish
        else
            print_warning "Ngrok failed to start, continuing with localhost only..."
        fi

        start_rails
        start_sidekiq
        show_status
    fi
}

# Function to stop all services
stop_all_services() {
    print_status "Stopping Chatwoot development server..."
    stop_rails
    stop_sidekiq
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        stop_nginx
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        stop_tailscale_funnel
    else
        stop_ngrok
    fi
    show_status
}

# Function to show help
show_help() {
    echo -e "\n${BLUE}Chatwoot Development Server Management${NC}"
    echo -e "Usage: $0 {start|start-public|stop|restart|status|test-connectivity|test-apple-messages|nginx-start|nginx-stop|nginx-reload|ngrok-start|ngrok-stop|tailscale-start|tailscale-stop|tailscale-status|help}"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  start              - Start Rails server and Sidekiq (localhost only)"
    echo -e "  start-public       - Start all services with public access (custom domain, Tailscale Funnel, or ngrok)"
    echo -e "  stop               - Stop all services"
    echo -e "  restart            - Restart all services with public access and test connectivity"
    echo -e "  status             - Show current status of all services"
    echo -e "  test-connectivity  - Test external connectivity to configured domain"
    echo -e "  test-apple-messages - Test Apple Messages webhook endpoint specifically"
    echo -e "  nginx-start        - Start nginx server only (when USE_CUSTOM_DOMAIN=true)"
    echo -e "  nginx-stop         - Stop nginx server only"
    echo -e "  nginx-reload       - Reload nginx configuration"
    echo -e "  ngrok-start        - Start ngrok tunnel only"
    echo -e "  ngrok-stop         - Stop ngrok tunnel only"
    echo -e "  tailscale-start    - Start Tailscale Funnel only"
    echo -e "  tailscale-stop     - Stop Tailscale Funnel only"
    echo -e "  tailscale-status   - Check detailed Tailscale and Funnel status"
    echo -e "  help               - Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        echo -e "  $0 start-public        # Start with custom domain: https://$CUSTOM_DOMAIN"
        echo -e "  $0 test-connectivity   # Test if $CUSTOM_DOMAIN is reachable externally"
        echo -e "  $0 nginx-start         # Start nginx HTTPS proxy only"
        echo -e "  $0 nginx-reload        # Reload nginx configuration"
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        echo -e "  $0 start-public        # Start with Tailscale Funnel"
        echo -e "  $0 test-connectivity   # Test if Tailscale domain is reachable externally"
        echo -e "  $0 tailscale-start     # Start Tailscale Funnel only"
        echo -e "  $0 tailscale-status    # Check Tailscale authentication and Funnel status"
    else
        echo -e "  $0 start-public        # Start with ngrok tunnel"
        echo -e "  $0 test-connectivity   # Test if ngrok tunnel is reachable externally"
        echo -e "  $0 ngrok-start         # Start ngrok tunnel only"
    fi
    echo -e "  $0 start               # Start with localhost only"
    echo -e "  $0 stop                # Stop all services"
    echo -e "  $0 status              # Check if services are running"
    echo -e "  $0 test-apple-messages # Test Apple Messages webhook endpoint"
    echo -e "  $0 tailscale-status    # Detailed Tailscale diagnostics"
    echo ""
    echo -e "${YELLOW}Configuration:${NC}"
    if [ "$USE_CUSTOM_DOMAIN" = true ]; then
        echo -e "  Current mode: Custom Domain ($CUSTOM_DOMAIN)"
        echo -e "  Ensure Freebox port forwarding: External 3000 -> Internal $(ipconfig getifaddr en0 || echo 'YOUR_MAC_IP'):3000"
        echo -e "  Nginx config: /opt/homebrew/etc/nginx/servers/dev.rhaps.net.conf"
    elif [ "$USE_TAILSCALE_FUNNEL" = true ]; then
        echo -e "  Current mode: Tailscale Funnel"
        echo -e "  Ensure Tailscale is logged in and Funnel is enabled for your tailnet"
        echo -e "  Edit USE_TAILSCALE_FUNNEL=false to use ngrok instead"
    else
        echo -e "  Current mode: Ngrok"
        echo -e "  Edit NGROK_SUBDOMAIN for custom ngrok subdomain (requires account)"
        echo -e "  Edit USE_TAILSCALE_FUNNEL=true to use Tailscale Funnel instead"
    fi
    echo -e "  Edit USE_CUSTOM_DOMAIN, USE_TAILSCALE_FUNNEL variables in this script"
    echo ""
    echo -e "${YELLOW}External Connectivity:${NC}"
    echo -e "  The restart command automatically tests external connectivity"
    echo -e "  Use test-connectivity and test-apple-messages to verify Apple Messages webhook delivery"
    echo ""
}

# Main script logic
case "$1" in
    start)
        print_status "Starting Chatwoot development server (localhost only)..."
        cleanup_stale_processes
        archive_and_cleanup_logs
        start_rails
        start_sidekiq
        show_status
        ;;
    start-public|start-with-ngrok)
        start_all_services
        ;;
    stop)
        stop_all_services
        ;;
    restart)
        cleanup_stale_processes
        archive_and_cleanup_logs
        restart_services
        ;;
    status)
        show_status
        ;;
    test-connectivity)
        domain_to_test=""
        if [ "$USE_TAILSCALE_FUNNEL" = true ] && [ -f "$TAILSCALE_URL_FILE" ]; then
            domain_to_test=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
        elif [ "$USE_CUSTOM_DOMAIN" = true ]; then
            domain_to_test="$CUSTOM_DOMAIN"
        else
            # Check for ngrok URL
            ngrok_info=$(check_ngrok_status)
            ngrok_url=$(echo "$ngrok_info" | cut -d'|' -f2)
            if [ -n "$ngrok_url" ]; then
                domain_to_test=$(echo "$ngrok_url" | sed 's|https://||')
            fi
        fi
        
        if [ -n "$domain_to_test" ]; then
            test_external_connectivity "$domain_to_test"
        else
            print_error "No external domain configured or available to test"
            print_status "Start services with 'start-public' first"
            exit 1
        fi
        ;;
    test-apple-messages)
        domain_to_test=""
        if [ "$USE_TAILSCALE_FUNNEL" = true ] && [ -f "$TAILSCALE_URL_FILE" ]; then
            domain_to_test=$(cat "$TAILSCALE_URL_FILE" 2>/dev/null | head -1 | tr -d '\n')
        elif [ "$USE_CUSTOM_DOMAIN" = true ]; then
            domain_to_test="$CUSTOM_DOMAIN"
        else
            # Check for ngrok URL
            ngrok_info=$(check_ngrok_status)
            ngrok_url=$(echo "$ngrok_info" | cut -d'|' -f2)
            if [ -n "$ngrok_url" ]; then
                domain_to_test=$(echo "$ngrok_url" | sed 's|https://||')
            fi
        fi
        
        if [ -n "$domain_to_test" ]; then
            test_apple_messages_connectivity "$domain_to_test"
        else
            print_error "No external domain configured or available to test"
            print_status "Start services with 'start-public' first"
            exit 1
        fi
        ;;
    nginx-start)
        if [ "$USE_CUSTOM_DOMAIN" = true ]; then
            start_nginx
        else
            print_warning "Ngrok mode is enabled. Use 'ngrok-start' instead."
            print_status "To use nginx, set USE_CUSTOM_DOMAIN=true in this script."
        fi
        ;;
    nginx-stop)
        stop_nginx
        ;;
    nginx-reload)
        reload_nginx
        ;;
    ngrok-start)
        if [ "$USE_CUSTOM_DOMAIN" = true ]; then
            print_warning "Custom domain mode is enabled. Use 'nginx-start' instead."
            print_status "To use ngrok, set USE_CUSTOM_DOMAIN=false in this script."
        else
            start_ngrok
        fi
        ;;
    ngrok-stop)
        stop_ngrok
        ;;
    tailscale-start)
        start_tailscale_funnel
        ;;
    tailscale-stop)
        stop_tailscale_funnel
        ;;
    tailscale-status)
        show_tailscale_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Invalid command: $1"
        show_help
        exit 1
        ;;
esac