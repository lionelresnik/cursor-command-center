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
    # Extract org from module path (e.g., github.com/aquasecurity/trivy -> aquasecurity)
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
                if [[ "$be" == *"$fe_base"* ]] || [[ "$be" == "atlas" ]] || [[ "$be" == *"-api" ]]; then
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
    
    cat > "$output_file" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Service Dependency Graph</title>
    <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            min-height: 100vh;
            color: white;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        h1 {
            text-align: center;
            margin-bottom: 10px;
            font-size: 2rem;
            background: linear-gradient(90deg, #00d9ff, #00ff88);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        .subtitle {
            text-align: center;
            opacity: 0.6;
            margin-bottom: 30px;
        }
        .graph-container {
            background: rgba(255,255,255,0.05);
            border-radius: 15px;
            padding: 30px;
            margin-bottom: 20px;
            min-height: 400px;
        }
        .mermaid {
            display: flex;
            justify-content: center;
        }
        .mermaid svg {
            max-width: 100%;
            height: auto;
        }
        .legend {
            display: flex;
            gap: 20px;
            justify-content: center;
            flex-wrap: wrap;
            margin-top: 20px;
            padding: 15px;
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
        }
        .legend-item {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 0.9rem;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            opacity: 0.5;
            font-size: 0.85rem;
        }
        .stats {
            text-align: center;
            margin-bottom: 20px;
            padding: 15px;
            background: rgba(0,217,255,0.1);
            border-radius: 10px;
            border: 1px solid rgba(0,217,255,0.3);
        }
        .stats span {
            margin: 0 15px;
        }
        .beta-banner {
            background: linear-gradient(90deg, rgba(255,193,7,0.15), rgba(255,152,0,0.15));
            border: 1px solid rgba(255,193,7,0.4);
            border-radius: 10px;
            padding: 12px 20px;
            margin-bottom: 20px;
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
            justify-content: center;
        }
        .beta-tag {
            background: linear-gradient(90deg, #ffc107, #ff9800);
            color: #000;
            padding: 4px 12px;
            border-radius: 20px;
            font-weight: bold;
            font-size: 0.8rem;
        }
        .beta-text {
            font-size: 0.85rem;
            opacity: 0.9;
        }
        .beta-text code {
            background: rgba(255,255,255,0.1);
            padding: 2px 6px;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔗 Service Dependency Graph</h1>
HTMLEOF

    echo "        <p class=\"subtitle\">Workspace: <strong>$workspace</strong> | Generated: $(date '+%Y-%m-%d %H:%M')</p>" >> "$output_file"
    echo "        <div class=\"stats\"><span>📦 <strong>$repo_count</strong> repositories</span></div>" >> "$output_file"
    
    cat >> "$output_file" << HTMLEOF
        
        <div class="beta-banner">
            <span class="beta-tag">🧪 BETA</span>
            <span class="beta-text">
                <strong>Zero AI tokens!</strong> Groupings detected via static file analysis (go.mod, package.json).
                Connections are basic heuristics — edit <code>docs/$workspace/architecture.md</code> to add accurate relationships.
            </span>
        </div>
        
        <div class="graph-container">
            <pre class="mermaid">
HTMLEOF

    echo "$mermaid_code" >> "$output_file"
    
    cat >> "$output_file" << 'HTMLEOF'
            </pre>
        </div>
        
        <div class="legend">
            <div class="legend-item">
                <span>🔷</span>
                <span>Go Service</span>
            </div>
            <div class="legend-item">
                <span>🐳</span>
                <span>Docker</span>
            </div>
            <div class="legend-item">
                <span>🏗️</span>
                <span>Terraform</span>
            </div>
            <div class="legend-item">
                <span>λ</span>
                <span>Lambda</span>
            </div>
            <div class="legend-item">
                <span>📦</span>
                <span>Node.js</span>
            </div>
            <div class="legend-item">
                <span>☁️</span>
                <span>Cloud Provider</span>
            </div>
        </div>
        
        <div class="footer">
            Generated by Cursor Command Center<br>
            Edit <code>docs/WORKSPACE/architecture.md</code> to customize connections
        </div>
    </div>
    
    <script>
        mermaid.initialize({
            startOnLoad: true,
            theme: 'dark',
            themeVariables: {
                primaryColor: '#3b82f6',
                primaryTextColor: '#fff',
                primaryBorderColor: '#60a5fa',
                lineColor: '#60a5fa',
                secondaryColor: '#1e3a5f',
                tertiaryColor: '#1a202c',
                background: '#1a1a2e',
                mainBkg: '#2d3748',
                nodeBorder: '#4fd1c5',
                clusterBkg: 'rgba(255,255,255,0.05)',
                clusterBorder: 'rgba(255,255,255,0.2)',
                titleColor: '#fff'
            },
            flowchart: {
                useMaxWidth: true,
                htmlLabels: true,
                curve: 'basis',
                rankSpacing: 80,
                nodeSpacing: 50
            }
        });
    </script>
</body>
</html>
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
                echo "  --all, -a     Generate for all workspaces"
                echo "  --help, -h    Show this help"
                echo ""
                echo "Examples:"
                echo "  ./graph.sh                    # Show workspace menu"
                echo "  ./graph.sh backend            # Specific workspace"
                echo "  ./graph.sh --all              # All workspaces"
                echo "  ./graph.sh backend --open     # Generate and open"
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
