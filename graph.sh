#!/bin/bash

# Cursor Command Center - Service Dependency Graph Generator
# Generates beautiful HTML visualization of service dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Config
CONFIG_FILE="$SCRIPT_DIR/config.json"
CONTEXTS_DIR="$SCRIPT_DIR/contexts"
DOCS_DIR="$SCRIPT_DIR/docs"

print_header() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BOLD}🔗 Service Dependency Graph Generator${NC}                       ${CYAN}║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get list of workspaces
get_workspaces() {
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE" | grep -o '"[^"]*"' | tr -d '"' | grep -v "workspaces" | head -20
    else
        ls "$CONTEXTS_DIR"/*.repos 2>/dev/null | xargs -I {} basename {} .repos
    fi
}

# Detect repo type based on files present (smarter detection)
detect_repo_type() {
    local repo_path="$1"
    
    # Check for serverless/lambda first (specific)
    if [ -f "$repo_path/serverless.yml" ] || [ -f "$repo_path/serverless.yaml" ]; then
        echo "lambda"
        return
    elif [ -f "$repo_path/template.yaml" ] || [ -f "$repo_path/template.yml" ]; then
        echo "sam"
        return
    fi
    
    # Check for Terraform
    if ls "$repo_path"/*.tf &>/dev/null 2>&1; then
        echo "terraform"
        return
    fi
    
    # Detect Go projects (check root AND subdirs, also look for .go files)
    if [ -f "$repo_path/go.mod" ]; then
        echo "go"
        return
    elif find "$repo_path" -maxdepth 2 -name "go.mod" 2>/dev/null | grep -q .; then
        echo "go"
        return
    elif find "$repo_path" -maxdepth 2 -name "*.go" 2>/dev/null | head -1 | grep -q .; then
        echo "go"
        return
    fi
    
    # Detect Node.js
    if [ -f "$repo_path/package.json" ]; then
        # Check if it's a UI/frontend
        if grep -q '"react"\|"vue"\|"angular"\|"next"\|"nuxt"' "$repo_path/package.json" 2>/dev/null; then
            echo "frontend"
        else
            echo "node"
        fi
        return
    fi
    
    # Python
    if [ -f "$repo_path/requirements.txt" ] || [ -f "$repo_path/setup.py" ] || [ -f "$repo_path/pyproject.toml" ]; then
        echo "python"
        return
    fi
    
    # Java/Kotlin
    if [ -f "$repo_path/pom.xml" ] || [ -f "$repo_path/build.gradle" ] || [ -f "$repo_path/build.gradle.kts" ]; then
        echo "java"
        return
    fi
    
    # Rust
    if [ -f "$repo_path/Cargo.toml" ]; then
        echo "rust"
        return
    fi
    
    # Documentation
    if [ -f "$repo_path/mkdocs.yml" ] || [ -f "$repo_path/docusaurus.config.js" ]; then
        echo "docs"
        return
    elif [[ "$(basename "$repo_path")" == *docs* ]] || [[ "$(basename "$repo_path")" == *documentation* ]]; then
        echo "docs"
        return
    fi
    
    # CI/CD or DevOps
    if [[ "$(basename "$repo_path")" == *cicd* ]] || [[ "$(basename "$repo_path")" == *devops* ]] || [[ "$(basename "$repo_path")" == *infra* ]]; then
        echo "devops"
        return
    fi
    
    # Fallback - check for common patterns in name
    local name=$(basename "$repo_path")
    if [[ "$name" == *-ui ]] || [[ "$name" == *-frontend ]] || [[ "$name" == ui-* ]]; then
        echo "frontend"
    elif [[ "$name" == *-api ]] || [[ "$name" == *-server ]] || [[ "$name" == *-service ]]; then
        echo "service"
    elif [[ "$name" == *-lambda* ]] || [[ "$name" == *-function* ]]; then
        echo "lambda"
    elif [[ "$name" == *-lib ]] || [[ "$name" == *-utils ]] || [[ "$name" == *-common ]]; then
        echo "library"
    else
        echo "unknown"
    fi
}

# Get icon for repo type
get_type_icon() {
    local type="$1"
    case "$type" in
        lambda|sam) echo "λ" ;;
        terraform) echo "🏗️" ;;
        go) echo "🔷" ;;
        node|service) echo "⚙️" ;;
        frontend) echo "🖥️" ;;
        python) echo "🐍" ;;
        java) echo "☕" ;;
        rust) echo "🦀" ;;
        docs) echo "📚" ;;
        devops) echo "🔧" ;;
        library) echo "📦" ;;
        *) echo "📁" ;;
    esac
}

# Get shape for Mermaid
get_mermaid_shape() {
    local type="$1"
    local name="$2"
    case "$type" in
        lambda|sam) echo "${name}[λ $name]" ;;
        terraform) echo "${name}[🏗️ $name]" ;;
        docker|container) echo "${name}[🐳 $name]" ;;
        go) echo "${name}[🔷 $name]" ;;
        node) echo "${name}[📦 $name]" ;;
        python) echo "${name}[🐍 $name]" ;;
        *) echo "${name}[$name]" ;;
    esac
}

# Parse terraform for resources
parse_terraform() {
    local repo_path="$1"
    local repo_name="$2"
    
    # Find all .tf files and extract resource types
    for tf_file in "$repo_path"/*.tf; do
        [ -f "$tf_file" ] || continue
        
        # Extract AWS resources
        grep -oE 'resource\s+"aws_[^"]+' "$tf_file" 2>/dev/null | sed 's/resource "//' | while read resource; do
            echo "TF_RESOURCE:$repo_name:$resource"
        done
        
        # Extract Azure resources
        grep -oE 'resource\s+"azurerm_[^"]+' "$tf_file" 2>/dev/null | sed 's/resource "//' | while read resource; do
            echo "TF_RESOURCE:$repo_name:$resource"
        done
        
        # Extract GCP resources
        grep -oE 'resource\s+"google_[^"]+' "$tf_file" 2>/dev/null | sed 's/resource "//' | while read resource; do
            echo "TF_RESOURCE:$repo_name:$resource"
        done
    done
}

# Parse go.mod for dependencies
parse_go_mod() {
    local repo_path="$1"
    local repo_name="$2"
    
    # Find go.mod (might be in root or subdir)
    local go_mod=""
    if [ -f "$repo_path/go.mod" ]; then
        go_mod="$repo_path/go.mod"
    else
        go_mod=$(find "$repo_path" -maxdepth 2 -name "go.mod" 2>/dev/null | head -1)
    fi
    
    [ -z "$go_mod" ] && return
    
    # Get module name
    local module=$(grep "^module " "$go_mod" | head -1 | awk '{print $2}')
    echo "GO_MODULE:$repo_name:$module"
    
    # Look for internal imports (same org - might indicate dependency)
    # Extract org from module path (e.g., github.com/myorg/myservice -> myorg)
    local org=$(echo "$module" | cut -d'/' -f2)
    
    if [ -n "$org" ]; then
        grep -E "github.com/$org/" "$go_mod" 2>/dev/null | grep -v "^module" | while read -r line; do
            # Extract the repo name from the import
            local dep_repo=$(echo "$line" | grep -oE "github.com/$org/[^/\"' ]+" | cut -d'/' -f3)
            [ -n "$dep_repo" ] && echo "INTERNAL_DEP:$repo_name:$dep_repo"
        done
    fi
    
    # Detect cloud dependencies for infrastructure hints
    if grep -qE "aws-sdk|github.com/aws" "$go_mod" 2>/dev/null; then
        echo "CLOUD_DEP:$repo_name:aws"
    fi
    if grep -qE "cloud.google.com|google-cloud" "$go_mod" 2>/dev/null; then
        echo "CLOUD_DEP:$repo_name:gcp"
    fi
    if grep -qE "azure-sdk|github.com/Azure" "$go_mod" 2>/dev/null; then
        echo "CLOUD_DEP:$repo_name:azure"
    fi
}

# Parse package.json for internal dependencies
parse_package_json() {
    local repo_path="$1"
    local repo_name="$2"
    
    [ ! -f "$repo_path/package.json" ] && return
    
    # Look for workspace dependencies or internal packages
    # This catches monorepo setups and private packages
    grep -oE '"@[^"]+/[^"]+"|"[^"]+":.*"workspace:' "$repo_path/package.json" 2>/dev/null | while read -r line; do
        local dep=$(echo "$line" | tr -d '"' | cut -d':' -f1 | sed 's/@[^/]*\///')
        [ -n "$dep" ] && echo "NPM_DEP:$repo_name:$dep"
    done
}

# Parse docker-compose
parse_docker_compose() {
    local repo_path="$1"
    local repo_name="$2"
    
    for compose_file in "$repo_path/docker-compose.yml" "$repo_path/docker-compose.yaml" "$repo_path/compose.yml"; do
        [ -f "$compose_file" ] || continue
        
        # Get service names (lines starting with 2 spaces followed by word and colon)
        grep -E "^  [a-zA-Z][a-zA-Z0-9_-]*:" "$compose_file" 2>/dev/null | sed 's/://g' | tr -d ' ' | while read svc; do
            echo "DOCKER_SVC:$repo_name:$svc"
        done
        
        # Get depends_on
        grep -A 5 "depends_on:" "$compose_file" 2>/dev/null | grep -E "^\s+- " | sed 's/.*- //' | while read dep; do
            echo "DOCKER_DEP:$repo_name:$dep"
        done
    done
}

# Main scanning function
scan_workspace() {
    local workspace="$1"
    local repos_file="$CONTEXTS_DIR/${workspace}.repos"
    
    if [ ! -f "$repos_file" ]; then
        echo "ERROR:No repos file found"
        return
    fi
    
    # Read repos (format: name|path or just path)
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        local repo_name=""
        local repo_path=""
        
        if [[ "$line" == *"|"* ]]; then
            repo_name=$(echo "$line" | cut -d'|' -f1)
            repo_path=$(echo "$line" | cut -d'|' -f2)
        else
            repo_path="$line"
            repo_name=$(basename "$repo_path")
        fi
        
        [ ! -d "$repo_path" ] && continue
        
        local repo_type=$(detect_repo_type "$repo_path")
        echo "REPO:$repo_name:$repo_type:$repo_path"
        
        # Type-specific parsing
        case "$repo_type" in
            terraform)
                parse_terraform "$repo_path" "$repo_name"
                ;;
            go)
                parse_go_mod "$repo_path" "$repo_name"
                ;;
            node|frontend|service)
                parse_package_json "$repo_path" "$repo_name"
                ;;
        esac
        
        # Also check for docker-compose in any repo
        parse_docker_compose "$repo_path" "$repo_name"
        
    done < "$repos_file"
}

# Generate Mermaid diagram from scan results
generate_mermaid() {
    local workspace="$1"
    local scan_file="$2"
    
    # Collect repos (bash 3 compatible - no associative arrays)
    local all_repos=""
    local tf_aws_repos=""
    local tf_gcp_repos=""
    local tf_azure_repos=""
    local go_repos=""
    local node_repos=""
    local frontend_repos=""
    local lambda_repos=""
    local python_repos=""
    local java_repos=""
    local docs_repos=""
    local devops_repos=""
    local library_repos=""
    local other_repos=""
    
    while IFS= read -r line; do
        case "$line" in
            REPO:*)
                local name=$(echo "$line" | cut -d: -f2)
                local type=$(echo "$line" | cut -d: -f3)
                all_repos="$all_repos $name"
                
                case "$type" in
                    terraform)
                        # Categorize by name or detected resources
                        if [[ "$name" == *aws* ]] || [[ "$name" == *AWS* ]]; then
                            tf_aws_repos="$tf_aws_repos $name"
                        elif [[ "$name" == *gcp* ]] || [[ "$name" == *GCP* ]] || [[ "$name" == *google* ]]; then
                            tf_gcp_repos="$tf_gcp_repos $name"
                        elif [[ "$name" == *azure* ]] || [[ "$name" == *Azure* ]]; then
                            tf_azure_repos="$tf_azure_repos $name"
                        else
                            tf_aws_repos="$tf_aws_repos $name"  # Default to AWS
                        fi
                        ;;
                    go) go_repos="$go_repos $name" ;;
                    node|service) node_repos="$node_repos $name" ;;
                    frontend) frontend_repos="$frontend_repos $name" ;;
                    lambda|sam) lambda_repos="$lambda_repos $name" ;;
                    python) python_repos="$python_repos $name" ;;
                    java) java_repos="$java_repos $name" ;;
                    docs) docs_repos="$docs_repos $name" ;;
                    devops) devops_repos="$devops_repos $name" ;;
                    library) library_repos="$library_repos $name" ;;
                    *) other_repos="$other_repos $name" ;;
                esac
                ;;
            TF_RESOURCE:*)
                local repo=$(echo "$line" | cut -d: -f2)
                local resource=$(echo "$line" | cut -d: -f3)
                # Move from other to specific cloud if we detect resources
                if [[ "$resource" == aws_* ]] && [[ ! " $tf_aws_repos " =~ " $repo " ]]; then
                    tf_aws_repos="$tf_aws_repos $repo"
                    other_repos=$(echo "$other_repos" | sed "s/ $repo / /g")
                elif [[ "$resource" == azurerm_* ]] && [[ ! " $tf_azure_repos " =~ " $repo " ]]; then
                    tf_azure_repos="$tf_azure_repos $repo"
                    other_repos=$(echo "$other_repos" | sed "s/ $repo / /g")
                elif [[ "$resource" == google_* ]] && [[ ! " $tf_gcp_repos " =~ " $repo " ]]; then
                    tf_gcp_repos="$tf_gcp_repos $repo"
                    other_repos=$(echo "$other_repos" | sed "s/ $repo / /g")
                fi
                ;;
        esac
    done < "$scan_file"
    
    # Generate Mermaid
    cat << EOF
---
config:
  layout: elk
  look: handDrawn
  theme: dark
  elk:
    mergeEdges: false
    nodePlacementStrategy: NETWORK_SIMPLEX
---
graph TB
    %% Auto-generated by Cursor Command Center
    %% Workspace: $workspace
    %% Generated: $(date '+%Y-%m-%d %H:%M')
    
EOF

    # Helper to add subgraph
    add_subgraph() {
        local title="$1"
        local icon="$2"
        local repos="$3"
        [ -z "$repos" ] && return 1
        
        echo "    subgraph ${title//[^a-zA-Z0-9]/_}[\"$icon $title\"]"
        for repo in $repos; do
            local safe_name=$(echo "$repo" | tr '-' '_' | tr '.' '_')
            echo "        ${safe_name}[\"$repo\"]"
        done
        echo "    end"
        echo ""
        return 0
    }
    
    # Add subgraphs based on what we found
    local has_content=false
    
    # Backend Services (Go)
    if [ -n "$go_repos" ]; then
        has_content=true
        add_subgraph "Go Services" "🔷" "$go_repos"
    fi
    
    # Node.js Services
    if [ -n "$node_repos" ]; then
        has_content=true
        add_subgraph "Node Services" "⚙️" "$node_repos"
    fi
    
    # Frontend
    if [ -n "$frontend_repos" ]; then
        has_content=true
        add_subgraph "Frontend" "🖥️" "$frontend_repos"
    fi
    
    # Lambda/Serverless
    if [ -n "$lambda_repos" ]; then
        has_content=true
        add_subgraph "Serverless" "λ" "$lambda_repos"
    fi
    
    # Python
    if [ -n "$python_repos" ]; then
        has_content=true
        add_subgraph "Python Services" "🐍" "$python_repos"
    fi
    
    # Java
    if [ -n "$java_repos" ]; then
        has_content=true
        add_subgraph "Java Services" "☕" "$java_repos"
    fi
    
    # Libraries/Utils
    if [ -n "$library_repos" ]; then
        has_content=true
        add_subgraph "Libraries" "📦" "$library_repos"
    fi
    
    # DevOps/CI
    if [ -n "$devops_repos" ]; then
        has_content=true
        add_subgraph "DevOps" "🔧" "$devops_repos"
    fi
    
    # Documentation
    if [ -n "$docs_repos" ]; then
        has_content=true
        add_subgraph "Documentation" "📚" "$docs_repos"
    fi
    
    # AWS Terraform
    if [ -n "$tf_aws_repos" ]; then
        has_content=true
        add_subgraph "AWS Infrastructure" "☁️" "$tf_aws_repos"
    fi
    
    # GCP Terraform
    if [ -n "$tf_gcp_repos" ]; then
        has_content=true
        add_subgraph "GCP Infrastructure" "☁️" "$tf_gcp_repos"
    fi
    
    # Azure Terraform
    if [ -n "$tf_azure_repos" ]; then
        has_content=true
        add_subgraph "Azure Infrastructure" "☁️" "$tf_azure_repos"
    fi
    
    # Other repos (uncategorized)
    if [ -n "$other_repos" ]; then
        has_content=true
        add_subgraph "Other" "📁" "$other_repos"
    fi
    
    # If nothing found, show all repos as simple list
    if [ "$has_content" = false ] && [ -n "$all_repos" ]; then
        add_subgraph "Repositories" "📁" "$all_repos"
    fi
    
    # Add detected connections
    echo ""
    echo "    %% === Auto-detected relationships (from go.mod/package.json) ==="
    
    # Process internal dependencies found during scanning
    local connections_added=""
    while IFS= read -r line; do
        case "$line" in
            INTERNAL_DEP:*)
                local from_repo=$(echo "$line" | cut -d: -f2)
                local to_repo=$(echo "$line" | cut -d: -f3)
                # Only add if both repos exist in our workspace
                if [[ " $all_repos " =~ " $to_repo " ]] || [[ " $all_repos " =~ " ${to_repo%-*} " ]]; then
                    local safe_from=$(echo "$from_repo" | tr '-' '_' | tr '.' '_')
                    local safe_to=$(echo "$to_repo" | tr '-' '_' | tr '.' '_')
                    local conn_key="${safe_from}_${safe_to}"
                    # Avoid duplicates
                    if [[ ! " $connections_added " =~ " $conn_key " ]]; then
                        echo "    ${safe_from} --> ${safe_to}"
                        connections_added="$connections_added $conn_key"
                    fi
                fi
                ;;
            DOCKER_DEP:*)
                local from_svc=$(echo "$line" | cut -d: -f2)
                local to_svc=$(echo "$line" | cut -d: -f3)
                local safe_from=$(echo "$from_svc" | tr '-' '_' | tr '.' '_')
                local safe_to=$(echo "$to_svc" | tr '-' '_' | tr '.' '_')
                echo "    ${safe_from} --> ${safe_to}"
                ;;
        esac
    done < "$scan_file"
    
    # Heuristic connections based on naming patterns
    echo ""
    echo "    %% === Heuristic connections (edit to refine) ==="
    
    # Frontend → APIs (dotted = suggested)
    if [ -n "$frontend_repos" ]; then
        for fe in $frontend_repos; do
            local safe_fe=$(echo "$fe" | tr '-' '_' | tr '.' '_')
            # Look for matching API/backend by name
            for be in $go_repos $node_repos; do
                # If frontend is "ui-foo" and backend is "foo" or "foo-api"
                local fe_base=$(echo "$fe" | sed 's/^ui-//' | sed 's/-ui$//' | sed 's/-frontend$//')
                if [[ "$be" == *"$fe_base"* ]] || [[ "$be" == *"-api" ]] || [[ "$be" == *"-backend" ]] || [[ "$be" == *"-server" ]]; then
                    local safe_be=$(echo "$be" | tr '-' '_' | tr '.' '_')
                    echo "    ${safe_fe} -.->|API| ${safe_be}"
                    break
                fi
            done
        done
    fi
    
    # Libraries used by services (if naming suggests it)
    if [ -n "$library_repos" ]; then
        for lib in $library_repos; do
            local safe_lib=$(echo "$lib" | tr '-' '_' | tr '.' '_')
            local lib_base=$(echo "$lib" | sed 's/-utils$//' | sed 's/-lib$//' | sed 's/-common$//')
            # Connect to services that might use this lib
            for svc in $go_repos; do
                if [[ "$svc" == *"$lib_base"* ]] || [[ "$lib" == "go-utils" ]] || [[ "$lib" == *"-go-utils" ]]; then
                    local safe_svc=$(echo "$svc" | tr '-' '_' | tr '.' '_')
                    echo "    ${safe_svc} -.-> ${safe_lib}"
                fi
            done
        done
    fi
    
    # Services → Infrastructure (Go/Node services that deploy to cloud)
    local all_services="$go_repos $node_repos"
    local all_infra="$tf_aws_repos $tf_gcp_repos $tf_azure_repos"
    if [ -n "$all_services" ] && [ -n "$all_infra" ]; then
        echo "    %% Services deploy to cloud infrastructure"
        for svc in $all_services; do
            [ -z "$svc" ] && continue
            local safe_svc=$(echo "$svc" | tr '-' '_' | tr '.' '_')
            
            # Connect to AWS
            for tf in $tf_aws_repos; do
                [ -z "$tf" ] && continue
                local safe_tf=$(echo "$tf" | tr '-' '_' | tr '.' '_')
                echo "    ${safe_svc} -.->|deploys| ${safe_tf}"
            done
            # Connect to GCP
            for tf in $tf_gcp_repos; do
                [ -z "$tf" ] && continue
                local safe_tf=$(echo "$tf" | tr '-' '_' | tr '.' '_')
                echo "    ${safe_svc} -.->|deploys| ${safe_tf}"
            done
            # Connect to Azure
            for tf in $tf_azure_repos; do
                [ -z "$tf" ] && continue
                local safe_tf=$(echo "$tf" | tr '-' '_' | tr '.' '_')
                echo "    ${safe_svc} -.->|deploys| ${safe_tf}"
            done
        done
    fi
    
    echo ""
    echo "    %% Edit this file to add custom connections"
    echo "    %% Example: service_a --> service_b"
}

# Generate HTML with embedded Mermaid
generate_html() {
    local workspace="$1"
    local mermaid_code="$2"
    local output_file="$3"
    local repo_count="$4"

    # Build EDGES JS array by parsing the mermaid source
    local edges_js=""
    while IFS= read -r line; do
        local stripped="${line#"${line%%[! ]*}"}"
        [[ "$stripped" == %* ]] && continue
        [[ "$stripped" == ---* ]] && continue
        [[ "$stripped" == config* ]] && continue
        [[ "$stripped" == layout* ]] && continue
        [[ "$stripped" == look* ]] && continue
        [[ "$stripped" == theme* ]] && continue
        [[ "$stripped" == elk* ]] && continue
        [[ "$stripped" == merge* ]] && continue
        [[ "$stripped" == node* ]] && continue
        # Match lines with an arrow: identifier --> identifier (with optional |label|)
        if [[ "$stripped" =~ ^([a-zA-Z0-9_]+)[[:space:]]*(-[.-]*\>|=[.=]*\>) ]]; then
            local src="${BASH_REMATCH[1]}"
            local tgt
            tgt=$(echo "$stripped" | sed -E 's/\|[^|]*\|//' | grep -oE '[a-zA-Z0-9_]+[[:space:]]*$' | tr -d ' \t')
            if [ -n "$src" ] && [ -n "$tgt" ] && [ "$src" != "$tgt" ]; then
                [ -n "$edges_js" ] && edges_js="${edges_js},"$'\n'
                edges_js="${edges_js}      ['${src}','${tgt}']"
            fi
        fi
    done <<< "$mermaid_code"

    cat > "$output_file" << 'HTMLEOF'
<!DOCTYPE html>
<html><head>
  <meta charset="utf-8">
  <title>Service Dependency Graph</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #1a1a2e;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      color: #e0e0e0;
      overflow: hidden;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }
    header { text-align: center; padding: 16px 20px 8px; flex-shrink: 0; }
    h1 { color: #4FC3F7; margin-bottom: 4px; font-size: 22px; }
    .subtitle { color: #90A4AE; margin-bottom: 4px; font-size: 13px; }
    .beta { color: #FFE082; margin-bottom: 10px; font-size: 12px; }
    .legend {
      display: inline-flex; flex-wrap: wrap; gap: 12px;
      padding: 8px 16px; background: rgba(255,255,255,0.05); border-radius: 8px; font-size: 12px;
    }
    .legend-item { display: flex; align-items: center; gap: 6px; }
    #viewport {
      flex: 1; overflow: hidden; position: relative; cursor: grab;
    }
    #viewport:active { cursor: grabbing; }
    #canvas { transform-origin: 0 0; position: absolute; top: 0; left: 0; }
    .controls {
      position: fixed; bottom: 24px; right: 24px;
      display: flex; flex-direction: column; gap: 6px; z-index: 100;
    }
    .controls button {
      width: 40px; height: 40px;
      border: 1px solid rgba(255,255,255,0.15); border-radius: 8px;
      background: rgba(26,26,46,0.9); color: #e0e0e0; font-size: 20px;
      cursor: pointer; display: flex; align-items: center; justify-content: center;
      backdrop-filter: blur(8px);
    }
    .controls button:hover { background: rgba(79,195,247,0.2); border-color: #4FC3F7; }
    .zoom-label { text-align: center; font-size: 11px; color: #90A4AE; padding: 2px 0; }
    .hint { position: fixed; bottom: 24px; left: 24px; font-size: 11px; color: rgba(255,255,255,0.3); z-index: 100; }
    #nodeInfo {
      position: fixed; top: 16px; right: 24px;
      background: rgba(26,26,46,0.95); border: 1px solid #4FC3F7; border-radius: 8px;
      padding: 14px 18px; font-size: 13px; z-index: 100; backdrop-filter: blur(8px);
      max-width: 320px; display: none;
    }
    #nodeInfo:not(.expanded) #nodeConns { max-height: 90px; overflow: hidden; }
    #nodeInfo.expanded #nodeConns { max-height: none; }
    #nodeInfo.expanded { max-height: 85vh; overflow-y: auto; }
    #nodeInfo .name { color: #4FC3F7; font-weight: bold; font-size: 15px; margin-bottom: 8px; }
    #nodeInfo .close-btn {
      position: absolute; top: 6px; right: 10px;
      background: none; border: none; color: #666; cursor: pointer; font-size: 16px;
    }
    #nodeInfo .close-btn:hover { color: #fff; }
    .expand-toggle {
      display: block; width: 100%; margin-top: 8px; padding: 5px 0;
      background: rgba(79,195,247,0.1); border: 1px solid rgba(79,195,247,0.3);
      border-radius: 4px; color: #4FC3F7; font-size: 11px; cursor: pointer; text-align: center;
    }
    .expand-toggle:hover { background: rgba(79,195,247,0.25); }
    .conn-section { margin-top: 6px; }
    .conn-header { font-weight: bold; font-size: 12px; }
    .conn-list { font-size: 12px; padding-left: 10px; }
    .conn-item { padding: 1px 0; }
  </style>
</head><body>
  <header>
HTMLEOF

    echo "    <h1>Service Dependency Graph</h1>" >> "$output_file"
    echo "    <p class=\"subtitle\">Workspace: <strong>${workspace}</strong> | Generated: $(date '+%Y-%m-%d') | ${repo_count} repos | Static analysis — zero AI tokens</p>" >> "$output_file"

    cat >> "$output_file" << 'HTMLEOF'
    <p class="beta">⚠ Beta — connections inferred from static files only. Runtime connections (HTTP calls, queues) not detected.</p>
    <div class="legend">
      <div class="legend-item">🔷 Go Service</div>
      <div class="legend-item">🏗️ Terraform</div>
      <div class="legend-item">λ Lambda</div>
      <div class="legend-item">📦 Node.js</div>
      <div class="legend-item">☁️ Cloud</div>
    </div>
  </header>

  <div id="viewport">
    <div id="canvas">
      <pre class="mermaid">
HTMLEOF

    echo "$mermaid_code" >> "$output_file"

    cat >> "$output_file" << 'HTMLEOF'
      </pre>
    </div>
  </div>

  <div class="controls">
    <button id="zoomIn" title="Zoom in">+</button>
    <div class="zoom-label" id="zoomLevel">100%</div>
    <button id="zoomOut" title="Zoom out">−</button>
    <button id="zoomReset" title="Fit to screen">⊡</button>
  </div>
  <div class="hint">Scroll to zoom · Drag to pan · Click a node to highlight its flow</div>

  <div id="nodeInfo">
    <button class="close-btn" onclick="clearHighlight()">✕</button>
    <div class="name" id="nodeName"></div>
    <div id="nodeConns"></div>
  </div>

  <script type="module">
    import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs';
    import elkLayouts from 'https://cdn.jsdelivr.net/npm/@mermaid-js/layout-elk@0/dist/mermaid-layout-elk.esm.min.mjs';

    await mermaid.registerLayoutLoaders(elkLayouts);
    mermaid.initialize({
      startOnLoad: false, securityLevel: 'loose', theme: 'dark',
      maxTextSize: 100000, flowchart: { useMaxWidth: false }
    });
    await mermaid.run();

    // ============================================================
    // EDGES — source of truth for connections (generated from Mermaid source)
    // ============================================================
    const EDGES = [
HTMLEOF

    # Write the dynamically generated edges
    echo "$edges_js" >> "$output_file"

    cat >> "$output_file" << 'HTMLEOF'
    ];

    // Build adjacency
    const adj = {};
    EDGES.forEach(([s,t]) => {
      if (!adj[s]) adj[s] = { out: new Set(), in: new Set() };
      if (!adj[t]) adj[t] = { out: new Set(), in: new Set() };
      adj[s].out.add(t);
      adj[t].in.add(s);
    });

    // ============================================================
    // MAP: Mermaid source ID → SVG element
    // ============================================================
    const svg = document.querySelector('svg');
    const allNodeEls    = [...svg.querySelectorAll('g.node, g[class*="node"]')];
    const rawEdgeEls    = [...svg.querySelectorAll('g.edge, g[class*="edge"]')];
    const allEdgeEls    = rawEdgeEls.filter(el => !el.querySelector('g.edge, g[class*="edge"]'));
    const allClusterEls = [...svg.querySelectorAll('g.cluster, g[class*="cluster"]')];

    const svgIdToSrcId = {};
    const srcIdToSvgEl = {};
    const srcIds = Object.keys(adj);

    allNodeEls.forEach(el => {
      const eid = el.id || '';
      let bestMatch = null, bestLen = 0;
      for (const sid of srcIds) {
        if (eid.includes(sid) && sid.length > bestLen) {
          bestMatch = sid; bestLen = sid.length;
        }
      }
      if (bestMatch) {
        svgIdToSrcId[eid] = bestMatch;
        srcIdToSvgEl[bestMatch] = el;
      }
    });

    const edgeToSrcTgt = new Map();
    allEdgeEls.forEach(el => {
      const eid = el.id || '';
      let bestSrc = null, bestTgt = null, bestScore = 0;
      for (const [s, t] of EDGES) {
        let score = 0;
        if (eid.includes(s)) score += s.length;
        if (eid.includes(t)) score += t.length;
        if (score > bestScore && eid.includes(s) && eid.includes(t)) {
          bestSrc = s; bestTgt = t; bestScore = score;
        }
      }
      if (bestSrc && bestTgt) edgeToSrcTgt.set(el, [bestSrc, bestTgt]);
    });

    // ============================================================
    // INJECT SVG <style> for reliable class-based highlighting
    // ============================================================
    const svgStyle = document.createElementNS('http://www.w3.org/2000/svg', 'style');
    svgStyle.textContent = `
      .node.arch-dimmed { visibility: hidden !important; pointer-events: none !important; }
      .node.arch-selected > rect, .node.arch-selected > polygon,
      .node.arch-selected > circle, .node.arch-selected > path {
        stroke: #4FC3F7 !important; stroke-width: 4px !important;
        filter: drop-shadow(0 0 14px #4FC3F7) drop-shadow(0 0 28px #4FC3F7) !important;
      }
      .node.arch-upstream > rect, .node.arch-upstream > polygon,
      .node.arch-upstream > circle, .node.arch-upstream > path {
        stroke: #FF9800 !important; stroke-width: 3px !important;
        filter: drop-shadow(0 0 10px #FF9800) !important;
      }
      .node.arch-downstream > rect, .node.arch-downstream > polygon,
      .node.arch-downstream > circle, .node.arch-downstream > path {
        stroke: #4CAF50 !important; stroke-width: 3px !important;
        filter: drop-shadow(0 0 10px #4CAF50) !important;
      }
      .cluster.arch-cluster-dimmed > rect,
      .cluster.arch-cluster-dimmed > path,
      .cluster.arch-cluster-dimmed > polygon { visibility: hidden !important; }
      .cluster.arch-cluster-dimmed > .cluster-label,
      .cluster.arch-cluster-dimmed > text,
      .cluster.arch-cluster-dimmed > foreignObject { visibility: hidden !important; }
      .cluster.arch-cluster-flow > rect,
      .cluster.arch-cluster-flow > path,
      .cluster.arch-cluster-flow > polygon { opacity: 0.3 !important; }
    `;
    svg.insertBefore(svgStyle, svg.firstChild);

    const archClasses = ['arch-dimmed','arch-selected','arch-upstream','arch-downstream','arch-cluster-dimmed','arch-cluster-flow'];
    function removeArchClasses(el) { archClasses.forEach(c => el.classList.remove(c)); }

    const highlightedEls = new Set();

    window.clearHighlight = function() {
      selectedSrcId = null;
      allNodeEls.forEach(n => removeArchClasses(n));
      allEdgeEls.forEach(e => removeArchClasses(e));
      allClusterEls.forEach(c => removeArchClasses(c));
      highlightedEls.forEach(el => {
        el.style.visibility = '';
        el.style.stroke = '';
        el.style.strokeWidth = '';
        el.style.fill = '';
        el.style.opacity = '';
      });
      highlightedEls.clear();
      document.getElementById('nodeInfo').style.display = 'none';
    };

    // ============================================================
    // PAN & ZOOM
    // ============================================================
    const viewport  = document.getElementById('viewport');
    const canvas    = document.getElementById('canvas');
    const zoomLabel = document.getElementById('zoomLevel');
    let scale = 1, panX = 0, panY = 0, isPanning = false, startX, startY;

    function applyTransform() {
      canvas.style.transform = `translate(${panX}px,${panY}px) scale(${scale})`;
      zoomLabel.textContent = Math.round(scale * 100) + '%';
    }
    function zoom(d, cx, cy) {
      const os = scale;
      scale = Math.min(3, Math.max(0.1, scale + d));
      const r = scale / os;
      panX = cx - r * (cx - panX);
      panY = cy - r * (cy - panY);
      applyTransform();
    }
    function fitToScreen() {
      if (!svg) return;
      const vw = viewport.clientWidth, vh = viewport.clientHeight;
      const sw = svg.getBoundingClientRect().width / scale;
      const sh = svg.getBoundingClientRect().height / scale;
      scale = Math.min(vw / sw, vh / sh) * 0.9;
      panX = (vw - sw * scale) / 2;
      panY = (vh - sh * scale) / 2;
      applyTransform();
    }

    viewport.addEventListener('wheel', e => {
      e.preventDefault();
      const r = viewport.getBoundingClientRect();
      zoom(e.deltaY > 0 ? -0.08 : 0.08, e.clientX - r.left, e.clientY - r.top);
    }, { passive: false });

    viewport.addEventListener('mousedown', e => {
      isPanning = true;
      startX = e.clientX - panX; startY = e.clientY - panY;
    });
    window.addEventListener('mousemove', e => {
      if (!isPanning) return;
      panX = e.clientX - startX; panY = e.clientY - startY;
      applyTransform();
    });
    window.addEventListener('mouseup', () => { isPanning = false; });

    document.getElementById('zoomIn').addEventListener('click',    () => { const r=viewport.getBoundingClientRect(); zoom( 0.15, r.width/2, r.height/2); });
    document.getElementById('zoomOut').addEventListener('click',   () => { const r=viewport.getBoundingClientRect(); zoom(-0.15, r.width/2, r.height/2); });
    document.getElementById('zoomReset').addEventListener('click', () => { window.clearHighlight(); fitToScreen(); });

    // ============================================================
    // CLICK TO HIGHLIGHT (BFS upstream + downstream)
    // ============================================================
    let selectedSrcId = null;

    function doHighlight(srcId) {
      if (!adj[srcId]) return;
      selectedSrcId = srcId;

      // BFS upstream
      const upstream = new Set();
      let q = [srcId], visited = new Set([srcId]);
      while (q.length) {
        const c = q.shift();
        for (const p of (adj[c]?.in || [])) {
          upstream.add(p);
          if (!visited.has(p)) { visited.add(p); q.push(p); }
        }
      }
      // BFS downstream
      const downstream = new Set();
      q = [srcId]; visited = new Set([srcId]);
      while (q.length) {
        const c = q.shift();
        for (const p of (adj[c]?.out || [])) {
          downstream.add(p);
          if (!visited.has(p)) { visited.add(p); q.push(p); }
        }
      }

      const flow = new Set([srcId, ...upstream, ...downstream]);

      // Apply classes to nodes
      allNodeEls.forEach(el => {
        removeArchClasses(el);
        const sid = svgIdToSrcId[el.id];
        if (sid && flow.has(sid)) {
          if (sid === srcId)         el.classList.add('arch-selected');
          else if (upstream.has(sid)) el.classList.add('arch-upstream');
          else                        el.classList.add('arch-downstream');
        } else {
          el.classList.add('arch-dimmed');
        }
      });

      // Hide all edges, then restore flow edges with color
      svg.querySelectorAll('.edgePaths path, .edgeLabels .edgeLabel, .edge path, .edge polygon, .edge line, .edge marker').forEach(el => {
        el.style.visibility = 'hidden';
        highlightedEls.add(el);
      });

      function restoreEdge(el, color) {
        el.querySelectorAll('path, polygon, line, circle, polyline').forEach(ch => {
          ch.style.visibility = 'visible';
          ch.style.stroke = color; ch.style.strokeWidth = '2px'; ch.style.opacity = '1';
          highlightedEls.add(ch);
        });
        el.querySelectorAll('text, tspan').forEach(ch => {
          ch.style.visibility = 'visible'; ch.style.fill = color; ch.style.opacity = '1';
          highlightedEls.add(ch);
        });
        el.querySelectorAll('marker path, marker polygon').forEach(ch => {
          ch.style.fill = color; ch.style.stroke = color; highlightedEls.add(ch);
        });
      }

      allEdgeEls.forEach(el => {
        const pair = edgeToSrcTgt.get(el);
        if (pair && flow.has(pair[0]) && flow.has(pair[1])) {
          const color = (pair[0] === srcId || pair[1] === srcId) ? '#4FC3F7'
                      : upstream.has(pair[0]) ? '#FF9800' : '#4CAF50';
          restoreEdge(el, color);
        }
      });

      // Fallback for unmapped edges
      svg.querySelectorAll('path[id], g[id]').forEach(el => {
        const eid = el.id || '';
        for (const [s, t] of EDGES) {
          if (flow.has(s) && flow.has(t) && eid.includes(s) && eid.includes(t)) {
            const color = (s === srcId || t === srcId) ? '#4FC3F7'
                        : upstream.has(s) ? '#FF9800' : '#4CAF50';
            if (el.tagName === 'path') {
              el.style.visibility = 'visible'; el.style.stroke = color;
              el.style.strokeWidth = '2px'; el.style.opacity = '1';
              highlightedEls.add(el);
            } else { restoreEdge(el, color); }
            break;
          }
        }
      });

      // Clusters
      allClusterEls.forEach(c => {
        removeArchClasses(c);
        const hasFlow = [...c.querySelectorAll('.node')].some(g => {
          const sid = svgIdToSrcId[g.id];
          return sid && flow.has(sid);
        });
        c.classList.add(hasFlow ? 'arch-cluster-flow' : 'arch-cluster-dimmed');
      });

      // Info panel
      const directIn   = [...(adj[srcId]?.in  || [])];
      const directOut  = [...(adj[srcId]?.out || [])];
      const allUp      = [...upstream];
      const allDown    = [...downstream];
      const infoEl     = document.getElementById('nodeInfo');

      document.getElementById('nodeName').textContent = srcId;

      let h = `<div style="color:#4FC3F7;margin-bottom:8px;font-size:12px;">Full flow: <b>${flow.size}</b> services</div>`;

      if (allUp.length) {
        h += `<div class="conn-section">`;
        h += `<div class="conn-header" style="color:#FF9800;">↑ Upstream (${allUp.length})</div>`;
        h += `<div class="conn-list">`;
        directIn.forEach(s => h += `<div class="conn-item" style="color:#FF9800;">${s} <span style="color:#666;font-size:10px;">direct</span></div>`);
        allUp.filter(s => !directIn.includes(s)).forEach(s => h += `<div class="conn-item" style="color:#FF9800;">${s}</div>`);
        h += `</div></div>`;
      }
      if (allDown.length) {
        h += `<div class="conn-section">`;
        h += `<div class="conn-header" style="color:#4CAF50;">↓ Downstream (${allDown.length})</div>`;
        h += `<div class="conn-list">`;
        directOut.forEach(s => h += `<div class="conn-item" style="color:#4CAF50;">${s} <span style="color:#666;font-size:10px;">direct</span></div>`);
        allDown.filter(s => !directOut.includes(s)).forEach(s => h += `<div class="conn-item" style="color:#4CAF50;">${s}</div>`);
        h += `</div></div>`;
      }
      if (!allUp.length && !allDown.length) h += '<div style="color:#666">No connections</div>';

      document.getElementById('nodeConns').innerHTML = h;
      infoEl.classList.remove('expanded');

      const totalItems = allUp.length + allDown.length;
      let toggleBtn = infoEl.querySelector('.expand-toggle');
      if (toggleBtn) toggleBtn.remove();
      if (totalItems > 3) {
        toggleBtn = document.createElement('button');
        toggleBtn.className = 'expand-toggle';
        toggleBtn.textContent = `Show all ${totalItems} connections`;
        toggleBtn.addEventListener('click', () => {
          const isExpanded = infoEl.classList.toggle('expanded');
          toggleBtn.textContent = isExpanded ? 'Collapse' : `Show all ${totalItems} connections`;
        });
        infoEl.appendChild(toggleBtn);
      } else { infoEl.classList.add('expanded'); }

      infoEl.style.display = 'block';
    }

    // Use mouseup to avoid drag conflicts
    let mouseDownPos = null;
    viewport.addEventListener('mousedown', e => { mouseDownPos = { x: e.clientX, y: e.clientY }; });
    viewport.addEventListener('mouseup', e => {
      if (!mouseDownPos) return;
      if (Math.abs(e.clientX - mouseDownPos.x) > 5 || Math.abs(e.clientY - mouseDownPos.y) > 5) return;

      const clickedEl = document.elementFromPoint(e.clientX, e.clientY);
      if (!clickedEl) return;

      let nodeG = clickedEl.closest ? clickedEl.closest('.node') : null;
      if (!nodeG) {
        let p = clickedEl;
        while (p && p !== svg) {
          if (p.classList && p.classList.contains('node')) { nodeG = p; break; }
          p = p.parentElement || p.parentNode;
        }
      }

      if (nodeG) {
        const sid = svgIdToSrcId[nodeG.id];
        if (sid) {
          if (selectedSrcId === sid) clearHighlight();
          else doHighlight(sid);
        }
      } else if (selectedSrcId) {
        clearHighlight();
      }
    });

    setTimeout(fitToScreen, 800);
  </script>
</body></html>
HTMLEOF
}

# Open graph in browser
open_in_browser() {
    local html_file="$1"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: try common browsers explicitly to avoid opening in Cursor/IDE
        if open -Ra "Google Chrome" &>/dev/null; then
            open -a "Google Chrome" "$html_file"
        elif open -Ra "Safari" &>/dev/null; then
            open -a "Safari" "$html_file"
        elif open -Ra "Firefox" &>/dev/null; then
            open -a "Firefox" "$html_file"
        elif open -Ra "Arc" &>/dev/null; then
            open -a "Arc" "$html_file"
        elif open -Ra "Brave Browser" &>/dev/null; then
            open -a "Brave Browser" "$html_file"
        else
            open "$html_file"
        fi
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$html_file"
    else
        echo "Open manually: $html_file"
        return 1
    fi
    return 0
}

# Main function
main() {
    local workspace=""
    local open_after=false
    local view_only=false
    local mermaid_file=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --open|-o)
                open_after=true
                shift
                ;;
            --view|-v)
                view_only=true
                shift
                ;;
            --mermaid-file|-m)
                mermaid_file="$2"
                shift 2
                ;;
            --all|-a)
                workspace="all"
                shift
                ;;
            --help|-h)
                echo "Usage: ./graph.sh [workspace] [options]"
                echo ""
                echo "Commands:"
                echo "  ./graph.sh [workspace]           Generate graph for workspace"
                echo "  ./graph.sh [workspace] --open    Generate AND open in browser"
                echo "  ./graph.sh [workspace] --view    Just open existing graph (no regenerate)"
                echo ""
                echo "Options:"
                echo "  --open, -o    Open graph in browser after generation"
                echo "  --view, -v    Just view existing graph (skip generation)"
                echo "  --mermaid-file, -m  Use external Mermaid file (skip scanning)"
                echo "  --all, -a     Generate for all workspaces"
                echo "  --help, -h    Show this help"
                echo ""
                echo "Examples:"
                echo "  ./graph.sh                    # Show workspace menu"
                echo "  ./graph.sh backend            # Specific workspace"
                echo "  ./graph.sh --all              # All workspaces"
                echo "  ./graph.sh backend --open     # Generate and open"
                echo "  ./graph.sh backend --mermaid-file /path/to/mermaid.md --open"
                exit 0
                ;;
            *)
                workspace="$1"
                shift
                ;;
        esac
    done
    
    print_header
    
    # Check config exists
    if [ ! -d "$CONTEXTS_DIR" ]; then
        print_error "No workspaces configured. Run ./setup.sh first."
        exit 1
    fi
    
    # Get workspaces to process
    local workspaces=()
    
    if [ -z "$workspace" ]; then
        # Show menu
        echo -e "${BOLD}Select a workspace:${NC}"
        echo ""
        
        local i=1
        declare -a ws_list
        for ws_file in "$CONTEXTS_DIR"/*.repos; do
            [ -f "$ws_file" ] || continue
            local ws_name=$(basename "$ws_file" .repos)
            [ "$ws_name" = "all" ] && continue
            [ "$ws_name" = "none" ] && continue
            ws_list+=("$ws_name")
            local count=$(wc -l < "$ws_file" | tr -d ' ')
            echo -e "  ${GREEN}$i)${NC} $ws_name ${DIM}($count repos)${NC}"
            ((i++))
        done
        
        echo ""
        echo -en "${MAGENTA}Enter number:${NC} "
        read -r choice
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#ws_list[@]}" ]; then
            workspace="${ws_list[$((choice-1))]}"
        else
            print_error "Invalid selection"
            exit 1
        fi
    fi
    
    if [ "$workspace" = "all" ]; then
        for ws_file in "$CONTEXTS_DIR"/*.repos; do
            [ -f "$ws_file" ] || continue
            local ws_name=$(basename "$ws_file" .repos)
            [ "$ws_name" = "all" ] && continue
            [ "$ws_name" = "none" ] && continue
            workspaces+=("$ws_name")
        done
    else
        workspaces+=("$workspace")
    fi
    
    if [ ${#workspaces[@]} -eq 0 ]; then
        print_error "No workspaces found"
        exit 1
    fi
    
    # View-only mode: just open existing graphs
    if [ "$view_only" = true ]; then
        for ws in "${workspaces[@]}"; do
            [ -z "$ws" ] && continue
            local html_file="$DOCS_DIR/$ws/architecture.html"
            if [ -f "$html_file" ]; then
                print_info "Opening graph for: ${BOLD}$ws${NC}"
                open_in_browser "$html_file"
            else
                print_warning "No graph found for '$ws'. Run './cc graph $ws' first to generate."
            fi
        done
        exit 0
    fi
    
    # Process each workspace
    for ws in "${workspaces[@]}"; do
        [ -z "$ws" ] && continue
        
        print_info "Processing workspace: ${BOLD}$ws${NC}"
        
        # Create docs directory for workspace
        local ws_docs_dir="$DOCS_DIR/$ws"
        mkdir -p "$ws_docs_dir"
        
        # External Mermaid mode (used by @lu / plugin)
        if [ -n "$mermaid_file" ]; then
            if [ ! -f "$mermaid_file" ]; then
                print_error "Mermaid file not found: $mermaid_file"
                continue
            fi
            
            local mermaid_code=$(cat "$mermaid_file")
            local repo_count=$(echo "$mermaid_code" | grep -c '^[[:space:]]*[a-zA-Z]' 2>/dev/null || echo "0")
            
            # Save Mermaid to .md file
            local md_file="$ws_docs_dir/architecture.md"
            cat > "$md_file" << MDEOF
# Architecture: $ws

> Generated: $(date '+%Y-%m-%d %H:%M') (from external Mermaid source)

## Dependency Graph

\`\`\`mermaid
$mermaid_code
\`\`\`

## Notes
- Connections inferred from static file analysis
- Runtime connections (HTTP calls, queues) not detected
- Edit this file to add custom connections
MDEOF
            
            print_success "Generated: $md_file"
            
            # Generate HTML
            local html_file="$ws_docs_dir/architecture.html"
            generate_html "$ws" "$mermaid_code" "$html_file" "$repo_count"
            print_success "Generated: $html_file"
            
            if [ "$open_after" = true ]; then
                print_info "Opening in browser..."
                open_in_browser "$html_file"
            fi
            
            echo ""
            continue
        fi
        
        # Scan workspace
        local scan_file=$(mktemp)
        scan_workspace "$ws" > "$scan_file"
        
        # Count repos
        local repo_count=$(grep "^REPO:" "$scan_file" | wc -l | tr -d ' ')
        print_info "  Found $repo_count repositories"
        
        # Show what was detected
        grep "^REPO:" "$scan_file" | while IFS=: read -r _ name type _; do
            local icon=$(get_type_icon "$type")
            echo -e "    ${DIM}$icon $name ($type)${NC}"
        done
        
        # Generate Mermaid
        local mermaid_code=$(generate_mermaid "$ws" "$scan_file")
        
        # Save Mermaid to .md file
        local md_file="$ws_docs_dir/architecture.md"
        cat > "$md_file" << EOF
# 🔗 Service Architecture - $ws

> Auto-generated by Cursor Command Center on $(date '+%Y-%m-%d %H:%M')
> **Edit this file to customize connections!**

## Dependency Graph

\`\`\`mermaid
$mermaid_code
\`\`\`

## Repositories

| Repo | Type | Description |
|------|------|-------------|
EOF
        
        grep "^REPO:" "$scan_file" | while IFS=: read -r _ name type path; do
            local icon=$(get_type_icon "$type")
            echo "| $icon $name | $type | Edit to add description |" >> "$md_file"
        done
        
        cat >> "$md_file" << 'EOF'

## How to Customize

1. Edit the Mermaid code above to add/remove connections
2. Add descriptions to the table
3. Re-run `./cc graph` to regenerate from config files (overwrites changes)

### Example Connections

```mermaid
%% Add these inside the graph TB block:
    service_a --> service_b
    service_a --> database[(Database)]
    service_b --> queue[/Queue/]
```
EOF
        
        print_success "Generated: $md_file"
        
        # Generate HTML
        local html_file="$ws_docs_dir/architecture.html"
        generate_html "$ws" "$mermaid_code" "$html_file" "$repo_count"
        print_success "Generated: $html_file"
        
        # Cleanup
        rm -f "$scan_file"
        
        # Open if requested
        if [ "$open_after" = true ]; then
            print_info "Opening in browser..."
            open_in_browser "$html_file"
        fi
        
        echo ""
    done
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}✅ Graph generation complete!${NC}"
    echo ""
    echo -e "View your graphs:"
    echo -e "  ${DIM}• HTML (interactive):${NC} docs/[workspace]/architecture.html"
    echo -e "  ${DIM}• Markdown (GitHub):${NC}  docs/[workspace]/architecture.md"
    echo ""
    echo -e "${DIM}Tip: Edit the .md file to add custom connections, then view in browser${NC}"
}

# Run
main "$@"
