#!/bin/bash

# ==============================================
# ANDISCAN - Android Security Audit Script
# ==============================================

cat << "EOF"
    _    _   _ ____ ___ 
   / \  | \ | |  _ \_ _|
  / _ \ |  \| | | | | | 
 / ___ \| |\  | |_| | | 
/_/   \_\_| \_|____/___|

ANDI - Android Inspector
by IoTSRG Team

EOF

timestamp=$(date +%Y%m%d_%H%M%S)
txt_dir="android_audit_output/txt_report_$timestamp"
html_dir="android_audit_output/html_report_$timestamp"
mkdir -p "$txt_dir" "$html_dir"

txt_file="$txt_dir/audit_report.txt"
html_file="$html_dir/audit_report.html"

critical_count=0
warning_count=0
safe_count=0
info_count=0

# ---- Fallback Functions for Property Lookup ----

get_prop_fallback() {
    for prop in "$@"; do
        value=$(adb shell getprop $prop | tr -d '\r')
        if [[ ! -z "$value" ]]; then
            echo "$value (from $prop)"
            return
        fi
    done
    echo "(unknown)"
}

get_prop_fallback_with_cpuinfo() {
    for prop in "$@"; do
        value=$(adb shell getprop $prop | tr -d '\r')
        if [[ ! -z "$value" ]]; then
            echo "$value (from $prop)"
            return
        fi
    done
    value=$(adb shell cat /proc/cpuinfo | grep -m1 -i 'hardware' | awk -F':' '{print $2}' | xargs)
    if [[ ! -z "$value" ]]; then
        echo "$value (from /proc/cpuinfo)"
        return
    fi
    echo "(unknown)"
}

# -----------------------------------------------

# HTML Header with modern template
cat <<EOF > "$html_file"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ANDI v2.0 - Advanced Android Security Audit</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/apexcharts"></script>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    :root {
      --primary: #4CAF50;
      --primary-dark: #388E3C;
      --secondary: #2196F3;
      --danger: #F44336;
      --warning: #FFC107;
      --info: #00BCD4;
      --dark: #21232a;
      --darker: #191b20;
      --light: #f7fafd;
      --lighter: #ffffff;
      --text-dark: #eeeeee;
      --text-light: #333333;
      --border-radius: 8px;
      --shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      --transition: all 0.3s ease;
    }

    body {
      font-family: 'Segoe UI', 'Roboto', Arial, sans-serif;
      background: var(--dark);
      color: var(--text-dark);
      margin: 0;
      line-height: 1.6;
    }

    .header {
      background: var(--darker);
      color: var(--text-dark);
      padding: 15px 30px;
      display: flex;
      align-items: center;
      gap: 20px;
      box-shadow: var(--shadow);
      position: sticky;
      top: 0;
      z-index: 100;
    }

    .header img {
      border-radius: 12px;
      border: 3px solid #333;
      background: #fff;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    }

    .header-content {
      flex: 1;
    }

    .header h1 {
      font-size: 1.8em;
      margin: 0;
      font-weight: 600;
      color: var(--primary);
    }

    .header p {
      margin: 5px 0 0;
      opacity: 0.8;
      font-size: 0.9em;
    }

    .theme-toggle {
      padding: 8px 20px;
      border-radius: var(--border-radius);
      background: var(--darker);
      color: var(--text-dark);
      border: 1px solid #444;
      font-weight: 500;
      cursor: pointer;
      transition: var(--transition);
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .theme-toggle:hover {
      background: #333;
    }

    .container {
      display: grid;
      grid-template-columns: 300px 1fr;
      gap: 20px;
      padding: 20px;
    }

    .sidebar {
      background: var(--darker);
      border-radius: var(--border-radius);
      padding: 20px;
      box-shadow: var(--shadow);
      height: fit-content;
      position: sticky;
      top: 90px;
    }

    .main-content {
      flex: 1;
    }

    .summary-card {
      background: var(--darker);
      border-radius: var(--border-radius);
      padding: 20px;
      margin-bottom: 20px;
      box-shadow: var(--shadow);
    }

    .summary-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 15px;
      margin-top: 15px;
    }

    .summary-item {
      background: #252525;
      border-radius: var(--border-radius);
      padding: 15px;
      text-align: center;
      transition: var(--transition);
    }

    .summary-item:hover {
      transform: translateY(-3px);
    }

    .summary-item i {
      font-size: 2em;
      margin-bottom: 10px;
    }

    .summary-item h3 {
      margin: 0;
      font-size: 1.2em;
    }

    .summary-item p {
      margin: 5px 0 0;
      font-size: 1.8em;
      font-weight: bold;
    }

    .safe { color: var(--primary); }
    .warning { color: var(--warning); }
    .critical { color: var(--danger); }
    .info { color: var(--secondary); }

    .search-bar {
      margin-bottom: 20px;
      position: relative;
    }

    .search-bar input {
      width: 100%;
      padding: 12px 15px 12px 40px;
      border-radius: var(--border-radius);
      border: 1px solid #444;
      background: #252525;
      color: var(--text-dark);
      font-size: 1em;
      transition: var(--transition);
    }

    .search-bar input:focus {
      outline: none;
      border-color: var(--primary);
      box-shadow: 0 0 0 2px rgba(76, 175, 80, 0.2);
    }

    .search-bar i {
      position: absolute;
      left: 15px;
      top: 50%;
      transform: translateY(-50%);
      color: #777;
    }

    .category-card {
      background: var(--darker);
      border-radius: var(--border-radius);
      margin-bottom: 20px;
      box-shadow: var(--shadow);
      overflow: hidden;
    }

    .category-header {
      background: #2a2a2a;
      padding: 15px 20px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: pointer;
      transition: var(--transition);
    }

    .category-header:hover {
      background: #333;
    }

    .category-header h2 {
      margin: 0;
      font-size: 1.3em;
      display: flex;
      align-items: center;
      gap: 10px;
    }

    .category-header .badge {
      padding: 3px 10px;
      border-radius: 20px;
      font-size: 0.8em;
      font-weight: 600;
    }

    .findings-list {
      padding: 0;
      margin: 0;
      list-style: none;
    }

    .finding-item {
      padding: 20px;
      border-bottom: 1px solid #333;
      transition: var(--transition);
    }

    .finding-item:last-child {
      border-bottom: none;
    }

    .finding-item:hover {
      background: #2a2a2a;
    }

    .finding-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 10px;
    }

    .finding-title {
      font-weight: 600;
      font-size: 1.1em;
      display: flex;
      align-items: center;
      gap: 8px;
    }

    .finding-severity {
      padding: 3px 10px;
      border-radius: 20px;
      font-size: 0.85em;
      font-weight: 600;
    }

    .finding-desc {
      color: #aaa;
      margin-bottom: 15px;
    }

    .finding-details {
      background: #252525;
      border-radius: var(--border-radius);
      padding: 15px;
      margin-top: 15px;
      font-family: 'Courier New', monospace;
      font-size: 0.9em;
      white-space: pre-wrap;
      word-break: break-all;
    }

    .finding-meta {
      display: flex;
      gap: 15px;
      margin-top: 15px;
      font-size: 0.85em;
      color: #777;
    }

    .finding-meta span {
      display: flex;
      align-items: center;
      gap: 5px;
    }

    .finding-actions {
      display: flex;
      gap: 10px;
      margin-top: 15px;
    }

    .btn {
      padding: 8px 15px;
      border-radius: var(--border-radius);
      border: none;
      font-weight: 500;
      cursor: pointer;
      transition: var(--transition);
      display: inline-flex;
      align-items: center;
      gap: 5px;
      font-size: 0.9em;
    }

    .btn-primary {
      background: var(--primary);
      color: white;
    }

    .btn-primary:hover {
      background: var(--primary-dark);
    }

    .btn-secondary {
      background: #444;
      color: white;
    }

    .btn-secondary:hover {
      background: #555;
    }

    .btn-outline {
      background: transparent;
      border: 1px solid #555;
      color: var(--text-dark);
    }

    .btn-outline:hover {
      border-color: #777;
    }

    .chart-container {
      height: 250px;
      margin-top: 20px;
    }

    .risk-meter {
      height: 10px;
      background: #333;
      border-radius: 5px;
      margin-top: 15px;
      overflow: hidden;
    }

    .risk-meter-fill {
      height: 100%;
      background: linear-gradient(90deg, var(--primary), var(--warning), var(--danger));
      border-radius: 5px;
    }

    .risk-labels {
      display: flex;
      justify-content: space-between;
      margin-top: 5px;
      font-size: 0.8em;
      color: #aaa;
    }

    /* Light theme */
    body.light {
      background: var(--light);
      color: var(--text-light);
    }

    body.light .header,
    body.light .sidebar,
    body.light .summary-card,
    body.light .category-card,
    body.light .category-header,
    body.light .finding-item,
    body.light .finding-details {
      background: var(--lighter);
    }

    body.light .header,
    body.light .category-header {
      border-bottom: 1px solid #eee;
    }

    body.light .finding-item {
      border-bottom: 1px solid #eee;
    }

    body.light .search-bar input,
    body.light .finding-details {
      background: #f5f5f5;
      color: #333;
    }

    body.light .finding-desc {
      color: #666;
    }

    body.light .theme-toggle {
      background: #f0f0f0;
      color: #333;
      border: 1px solid #ddd;
    }

    body.light .summary-item {
      background: #f5f5f5;
    }

    /* Responsive */
    @media (max-width: 1200px) {
      .container {
        grid-template-columns: 1fr;
      }
      
      .sidebar {
        position: static;
      }
      
      .summary-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    @media (max-width: 768px) {
      .header {
        flex-direction: column;
        text-align: center;
        padding: 15px;
      }
      
      .theme-toggle {
        margin-top: 10px;
      }
      
      .summary-grid {
        grid-template-columns: 1fr;
      }
    }
  </style>
</head>
<body class="dark">
  <div class="header">
    <img src="data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA1MTIgNTEyIj48cGF0aCBmaWxsPSIjM2VkOTVjIiBkPSJNMjU2IDhDMTE5IDggOCAxMTkgOCAyNTZzMTExIDI0OCAyNDggMjQ4IDI0OC0xMTEgMjQ4LTI0OFMzOTMgOCAyNTYgOHptMCA0NDhjLTExMC41IDAtMjAwLTg5LjUtMjAwLTIwMFMxNDUuNSA1NiAyNTYgNTZzMjAwIDg5LjUgMjAwIDIwMC04OS41IDIwMC0yMDAgMjAwWm0xMDEuOC0yNjEuN2wtODQuOS02MS43Yy0zLjEtMi4yLTcuMi0yLjItMTAuMyAwbC04NC45IDYxLjdjLTMuOSAyLjgtNC4xIDguMi0uNCAxMS4ybDQwLjQgMjkuNGMtMS44IDYuOC0yLjcgMTMuOS0yLjcgMjEuMXYzMmMwIDguOCA3LjIgMTYgMTYgMTZoMzJjOC44IDAgMTYtNy4yIDE2LTE2di0zMmMwLTcuMi0uOS0xNC4zLTIuNy0yMS4xbDQwLjQtMjkuNGMzLjgtMyA0LjEtOC40LjQtMTEuMloiLz48L3N2Zz4=" width="50" height="50" alt="ANDI Logo">
    <div class="header-content">
      <h1>ANDI v2.0 Security Audit</h1>
      <p>Comprehensive Android Device Inspection Report - Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
    </div>
    <button class="theme-toggle" onclick="document.body.classList.toggle('light')">
      <i class="fas fa-moon"></i> Theme
    </button>
  </div>

  <div class="container">
    <div class="sidebar">
      <div class="summary-card">
        <h2><i class="fas fa-chart-pie"></i> Security Summary</h2>
        <div class="chart-container" id="summaryChart"></div>
        <div class="risk-meter">
          <div class="risk-meter-fill" style="width: 65%;"></div>
        </div>
        <div class="risk-labels">
          <span>Low</span>
          <span>Medium</span>
          <span>High</span>
        </div>
      </div>

      <div class="summary-card">
        <h2><i class="fas fa-shield-alt"></i> Quick Stats</h2>
        <div class="summary-grid">
          <div class="summary-item">
            <i class="fas fa-check-circle safe"></i>
            <h3>Secure</h3>
            <p id="safeCount">0</p>
          </div>
          <div class="summary-item">
            <i class="fas fa-exclamation-triangle warning"></i>
            <h3>Warnings</h3>
            <p id="warnCount">0</p>
          </div>
          <div class="summary-item">
            <i class="fas fa-times-circle critical"></i>
            <h3>Critical</h3>
            <p id="critCount">0</p>
          </div>
          <div class="summary-item">
            <i class="fas fa-info-circle info"></i>
            <h3>Info</h3>
            <p id="infoCount">0</p>
          </div>
        </div>
      </div>

      <div class="summary-card">
        <h2><i class="fas fa-bolt"></i> Quick Actions</h2>
        <div class="finding-actions" style="flex-direction: column; gap: 10px;">
          <button class="btn btn-primary">
            <i class="fas fa-download"></i> Export Report
          </button>
          <button class="btn btn-secondary">
            <i class="fas fa-share-alt"></i> Share Findings
          </button>
          <button class="btn btn-outline">
            <i class="fas fa-question-circle"></i> Help & Docs
          </button>
        </div>
      </div>
    </div>

    <div class="main-content">
      <div class="search-bar">
        <i class="fas fa-search"></i>
        <input type="text" id="searchInput" placeholder="Search findings...">
      </div>

      <div id="findingsContainer">
        <!-- Dynamic content will be inserted here -->
      </div>
    </div>
  </div>

  <script>
    // Audit data will be populated by the script
    const auditData = [];
    
    // Function to render findings in the HTML
    function renderFindings() {
      const container = document.getElementById('findingsContainer');
      container.innerHTML = '';
      
      // Group by category
      const categories = [...new Set(auditData.map(item => item.category))];
      
      categories.forEach(category => {
        const categoryFindings = auditData.filter(item => item.category === category);
        
        const categoryCard = document.createElement('div');
        categoryCard.className = 'category-card';
        
        const header = document.createElement('div');
        header.className = 'category-header';
        header.innerHTML = `
          <h2>
            <i class="fas fa-folder"></i> ${category}
            <span class="badge">${categoryFindings.length} findings</span>
          </h2>
          <i class="fas fa-chevron-down"></i>
        `;
        
        const findingsList = document.createElement('ul');
        findingsList.className = 'findings-list';
        
        categoryFindings.forEach(finding => {
          const findingItem = document.createElement('li');
          findingItem.className = 'finding-item';
          
          findingItem.innerHTML = `
            <div class="finding-header">
              <div class="finding-title">
                <i class="fas fa-${getSeverityIcon(finding.severity)}"></i>
                ${finding.title}
              </div>
              <span class="finding-severity ${finding.severity}">${finding.severity.toUpperCase()}</span>
            </div>
            <div class="finding-desc">${finding.description}</div>
            <div class="finding-details">${formatResult(finding.result)}</div>
            <div class="finding-meta">
              <span><i class="fas fa-terminal"></i> ${finding.command}</span>
              <span><i class="fas fa-clock"></i> ${new Date(finding.timestamp).toLocaleString()}</span>
            </div>
            ${finding.remediation ? `
            <div class="finding-actions">
              <button class="btn btn-primary">
                <i class="fas fa-wrench"></i> Remediation
              </button>
              <button class="btn btn-outline">
                <i class="fas fa-book"></i> Documentation
              </button>
            </div>
            ` : ''}
          `;
          
          findingsList.appendChild(findingItem);
        });
        
        categoryCard.appendChild(header);
        categoryCard.appendChild(findingsList);
        container.appendChild(categoryCard);
        
        // Add click handler for category headers
        header.addEventListener('click', function() {
          findingsList.style.display = findingsList.style.display === 'none' ? 'block' : 'none';
          const icon = this.querySelector('.fa-chevron-down');
          icon.classList.toggle('fa-chevron-up');
        });
      });
    }

    // Format result for display
    function formatResult(result) {
      if (!result || result.trim() === '') return '<em>No output</em>';
      return result.toString().replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    // Get appropriate icon for severity level
    function getSeverityIcon(severity) {
      switch(severity) {
        case 'safe': return 'check-circle';
        case 'warning': return 'exclamation-triangle';
        case 'critical': return 'times-circle';
        default: return 'info-circle';
      }
    }

    // Update summary counts
    function updateSummaryCounts() {
      const counts = {
        safe: auditData.filter(item => item.severity === 'safe').length,
        warning: auditData.filter(item => item.severity === 'warning').length,
        critical: auditData.filter(item => item.severity === 'critical').length,
        info: auditData.filter(item => item.severity === 'info').length
      };
      
      document.getElementById('safeCount').textContent = counts.safe;
      document.getElementById('warnCount').textContent = counts.warning;
      document.getElementById('critCount').textContent = counts.critical;
      document.getElementById('infoCount').textContent = counts.info;
      
      // Update risk meter based on critical findings
      const riskPercentage = Math.min(100, (counts.critical * 10 + counts.warning * 5));
      document.querySelector('.risk-meter-fill').style.width = riskPercentage + '%';
      
      return counts;
    }

    // Render charts
    function renderCharts() {
      const counts = updateSummaryCounts();
      
      const options = {
        series: [counts.safe, counts.warning, counts.critical, counts.info],
        chart: {
          type: 'donut',
          height: '100%'
        },
        labels: ['Secure', 'Warnings', 'Critical', 'Info'],
        colors: ['#4CAF50', '#FFC107', '#F44336', '#00BCD4'],
        legend: {
          position: 'bottom'
        },
        responsive: [{
          breakpoint: 480,
          options: {
            chart: {
              width: 200
            },
            legend: {
              position: 'bottom'
            }
          }
        }]
      };
      
      const chart = new ApexCharts(document.querySelector("#summaryChart"), options);
      chart.render();
    }

    // Setup search functionality
    function setupSearch() {
      const searchInput = document.getElementById('searchInput');
      
      searchInput.addEventListener('input', function() {
        const searchTerm = this.value.toLowerCase();
        
        document.querySelectorAll('.finding-item').forEach(item => {
          const text = item.textContent.toLowerCase();
          item.style.display = text.includes(searchTerm) ? '' : 'none';
        });
      });
    }
    
    // Initialize when DOM is loaded
    document.addEventListener('DOMContentLoaded', function() {
      // Populate auditData from the script
      const auditDataScript = document.createElement('script');
      auditDataScript.textContent = window.auditDataRaw;
      document.body.appendChild(auditDataScript);
      
      renderFindings();
      renderCharts();
      setupSearch();
    });
  </script>
EOF

# Check ADB connection
if ! adb get-state 1>/dev/null 2>&1; then
  echo "[X] No device detected via ADB"
  exit 1
fi

# === DEVICE INFO COLLECTION WITH FALLBACKS ===
model=$(get_prop_fallback ro.product.model ro.product.device ro.product.name)
brand=$(get_prop_fallback ro.product.brand ro.product.manufacturer)
manufacturer=$(get_prop_fallback ro.product.manufacturer ro.product.brand)
name=$(get_prop_fallback ro.product.name ro.product.model)
soc_manufacturer=$(get_prop_fallback ro.soc.manufacturer ro.board.platform ro.hardware)
soc_model=$(get_prop_fallback_with_cpuinfo ro.soc.model ro.hardware ro.board.platform)
android_version=$(adb shell getprop ro.build.version.release | tr -d '\r')
sdk_level=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
build_id=$(adb shell getprop ro.build.display.id | tr -d '\r')
fingerprint=$(adb shell getprop ro.build.fingerprint | tr -d '\r')
serialno=$(adb shell getprop ro.serialno | tr -d '\r')
[[ -z "$serialno" ]] && serialno=$(adb shell getprop ro.boot.serialno | tr -d '\r')
timezone=$(adb shell getprop persist.sys.timezone | tr -d '\r')

# --- Clean output (strip fallback labels for report) ---
clean_model=$(echo "$model" | sed 's/ (from .*//')
clean_brand=$(echo "$brand" | sed 's/ (from .*//')
clean_manufacturer=$(echo "$manufacturer" | sed 's/ (from .*//')
clean_name=$(echo "$name" | sed 's/ (from .*//')
clean_soc_manufacturer=$(echo "$soc_manufacturer" | sed 's/ (from .*//')
clean_soc_model=$(echo "$soc_model" | sed 's/ (from .*//')

# --- TXT Report Output ---
echo -e "Model: $clean_model\nBrand: $clean_brand\nManufacturer: $clean_manufacturer\nName: $clean_name\nSoC Manufacturer: $clean_soc_manufacturer\nSoC Model: $clean_soc_model\nAndroid Version: $android_version\nSDK Level: $sdk_level\nBuild ID: $build_id\nFingerprint: $fingerprint\nSerial Number: $serialno\nTimezone: $timezone" >> "$txt_file"

# Add device info to HTML via JavaScript
cat <<EOF >> "$html_file"
  <script>
    // Add device info to the first category
    window.auditDataRaw = \`
    {
      "category": "Device Information",
      "title": "Device Details",
      "description": "Basic device information collected from system properties",
      "command": "getprop",
      "result": "Model: $clean_model\\nBrand: $clean_brand\\nManufacturer: $clean_manufacturer\\nName: $clean_name\\nSoC Manufacturer: $clean_soc_manufacturer\\nSoC Model: $clean_soc_model\\nAndroid Version: $android_version\\nSDK Level: $sdk_level\\nBuild ID: $build_id\\nFingerprint: $fingerprint\\nSerial Number: $serialno\\nTimezone: $timezone",
      "severity": "info",
      "remediation": "",
      "reference": "",
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    }\`;
  </script>
EOF

# Check Function
evaluate_check() {
    local category="$1"
    local label="$2"
    local command="$3"
    local safe_pattern="$4"
    local level="$5"
    local desc="$6"

    result=$(adb shell "$command" 2>/dev/null | tr -d '\r')
    [[ -z "$result" ]] && result="[Not Supported]"

    echo -e "
# === $category ===
Check: $label
Command: $command
Description: $desc
Result: $result" >> "$txt_file"

    # Determine status
    local status="info"
    if [[ "$result" != "[Not Supported]" ]]; then
        if [[ "$result" =~ $safe_pattern ]]; then
            status="safe"
            ((safe_count++))
        else
            case "$level" in
                critical) 
                    status="critical"
                    ((critical_count++))
                    ;;
                warning) 
                    status="warning"
                    ((warning_count++))
                    ;;
                *) 
                    status="info"
                    ((info_count++))
                    ;;
            esac
        fi
    else
        status="info"
        ((info_count++))
    fi

    # Add to HTML via JavaScript
    cat <<EOF >> "$html_file"
    <script>
      window.auditDataRaw += \`,
      {
        "category": "$category",
        "title": "$label",
        "description": "$desc",
        "command": "$command",
        "result": "${result//\"/\\\"}",
        "severity": "$status",
        "remediation": "$([[ "$status" != "safe" && "$status" != "info" ]] && echo "Review and fix according to security guidelines")",
        "reference": "",
        "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
      }\`;
    </script>
EOF
}

# === SECURITY CHECKS ===
# (All your existing evaluate_check calls go here, exactly as they were)

# USER & PRIVACY
evaluate_check "USER & PRIVACY" "Screen Lock" "dumpsys keyguard | grep 'secure=true'" "secure=true" "critical" "Screen lock must be enabled"
evaluate_check "USER & PRIVACY" "Clipboard Access" "cmd clipboard get-primary-clip" "^$" "safe" "Check if clipboard has sensitive data"
evaluate_check "USER & PRIVACY" "Location Services" "settings get secure location_mode" "^3$" "safe" "Mode 3 means high-accuracy enabled"
evaluate_check "USER & PRIVACY" "Show passwords disabled" "settings get system show_password" "0" "medium" "Password characters must not be shown"
evaluate_check "USER & PRIVACY" "Clipboard History" "dumpsys clipboard | grep 'Historical'" "^$" "warning" "Clipboard history should be disabled to prevent data leaks"
evaluate_check "USER & PRIVACY" "Biometric Strength" "dumpsys biometric | grep 'Strength='" "STRONG" "warning" "Biometric auth should be 'STRONG' (not 'WEAK')"
evaluate_check "USER & PRIVACY" "Backup Allowed" "settings get global backup_enabled" "0" "warning" "Auto-backup should be disabled for sensitive apps"
evaluate_check "USER & PRIVACY" "Fingerprint / Setup Complete" "settings get secure user_setup_complete" "^1$" "info" "Check if device setup is complete"
evaluate_check "USER & PRIVACY" "Trust Agents Enabled" "settings get secure enabled_trust_agents" "^$" "warning" "May allow unlock bypass via smart lock"
evaluate_check "USER & PRIVACY" "Microphone Usage" "dumpsys media.audio_flinger | grep -i active" "^$" "info" "Detects open microphones"
evaluate_check "USER & PRIVACY" "Camera Usage" "dumpsys media.camera | grep -i client" "^$" "info" "Detects active camera clients"
evaluate_check "USER & PRIVACY" "Sensors in Use" "dumpsys sensorservice | grep 'active' | grep -v '0'" "^$" "info" "Shows currently used sensors"
evaluate_check "USER & PRIVACY" "Network Telemetry" "settings get global usage_reporting_enabled" "^0$" "safe" "Should be disabled unless required"


# BOOT & SECURITY
evaluate_check "BOOT & SECURITY" "Verified Boot State" "getprop ro.boot.verifiedbootstate" "^green$" "critical" "Should be green for locked bootloader"
evaluate_check "BOOT & SECURITY" "Encryption" "getprop ro.crypto.state" "^encrypted$" "critical" "Storage should be encrypted"
evaluate_check "BOOT & SECURITY" "SELinux" "getenforce" "^Enforcing$" "warning" "SELinux should be enforcing"
evaluate_check "BOOT & SECURITY" "OEM Unlock Allowed" "getprop sys.oem_unlock_allowed" "^0$" "critical" "Should be disabled to prevent unlock"
evaluate_check "BOOT & SECURITY" "USB Debugging" "settings get global adb_enabled" "^0$" "warning" "Disable unless needed"
evaluate_check "BOOT & SECURITY" "Unknown Sources" "settings get secure install_non_market_apps" "^0$" "warning" "Should be disabled"
evaluate_check "BOOT & SECURITY" "Device Debuggable" "getprop ro.debuggable" "^0$" "critical" "Production devices must not be debuggable"
evaluate_check "BOOT & SECURITY" "Safe Mode" "getprop persist.sys.safemode" "^0$" "info" "Should not be running in Safe Mode"
evaluate_check "BOOT & SECURITY" "FRP Policy" "settings get global frp_policy" "^1$" "critical" "Factory Reset Protection should be enabled"
evaluate_check "BOOT & SECURITY" "ADB Over Wi-Fi" "settings get global adb_wifi_enabled" "^0$" "warning" "Risky if enabled"
evaluate_check "BOOT & SECURITY" "Bootloader Locked" "getprop ro.boot.flash.locked" "^1$" "critical" "1 means locked bootloader; 0 means unlocked"
evaluate_check "BOOT & SECURITY" "AVB Version" "getprop ro.boot.avb_version" ".*" "info" "Android Verified Boot version info"
evaluate_check "BOOTLOADER" "Fastboot Unlock Allowed" "getprop ro.oem_unlock_supported" "0" "critical" "Fastboot OEM unlock must be disabled"

# APPS & RUNTIME
evaluate_check "APPS & RUNTIME" "Root Access (su)" "which su" "^$" "critical" "Check for root binaries"
evaluate_check "APPS & RUNTIME" "Debuggable Apps" "pm list packages -d | wc -l" "^0$" "warning" "Debuggable apps should be 0"
evaluate_check "APPS & RUNTIME" "Accessibility Services" "settings get secure enabled_accessibility_services" "^$" "warning" "Keylogging/clickjacking risk"
evaluate_check "APPS & RUNTIME" "Device Admin Apps" "dumpsys device_policy | grep 'Admin:' | wc -l" "^0$" "warning" "Admins may have control"
evaluate_check "APPS & RUNTIME" "Running Services Count" "dumpsys activity services | grep -E 'package|process' | wc -l" ".*" "info" "Running services on device"
evaluate_check "APPS" "Suspicious APK Names" "pm list packages | grep -Ei 'hacker|spy|monitor|remote|keylog|shell'" "^$" "critical" "Packages with suspicious names"
evaluate_check "ROOT" "Systemless Root Path" "ls /sbin | grep magisk" "^$" "critical" "Magisk binary indicates systemless root"
evaluate_check "FRIDA" "Frida Server Listening" "ps | grep frida-server" "^$" "critical" "Frida server process found"


# NETWORK 
# evaluate_check "NETWORK" "Open Ports" "netstat -tuln | grep -E '0.0.0.0|::'" "^\s*$" "info" "No open TCP/UDP ports"

evaluate_check "NETWORK-IPV4" "All Active TCP Connections (IPv4)" "netstat -lntp | awk '\$1 == \"tcp\" && \$4 ~ /^[0-9.]+:/ { print \$0 }'" "^\s*$" "info" "Lists all IPv4 TCP connections including localhost — use for full socket audit"

evaluate_check "NETWORK-IPV4" "Common TCP Ports Exposed (IPv4, Warning)" "netstat -lnpt | awk '\$1 == \"tcp\" && \$6 == \"LISTEN\" && \$4 ~ /:((53)|(80)|(25)|(110)|(143)|(465)|(587)|(993)|(995)|(8080)|(8443)|(22))$/ && \$4 !~ /^127\\./'" "^\s*$" "warning" "One or more common TCP ports are externally accessible on IPv4 — review exposure"

evaluate_check "NETWORK-IPV4" "Expanded Critical TCP Ports (excluding SSH) Listening or External (IPv4)" "netstat -lnpt | awk '\$1 == \"tcp\" && \$6 == \"LISTEN\" && \$4 ~ /:((21)|(23)|(25)|(445)|(3306)|(5432)|(5900)|(5901)|(3389)|(5555)|(4444)|(8080)|(8443)|(41795))$/ && \$4 !~ /^127\\./'" "^\s*$" "critical" "One or more critical TCP ports (excluding SSH) are open or externally connected (IPv4) — review exposure"

evaluate_check "NETWORK-IPV4" "Open UDP Ports (IPv4, excluding localhost)" "netstat -lnup | awk '\$1 == \"udp\" && \$4 !~ /^127\\./'" "^\s*$" "info" "Open UDP ports (IPv4) found that are not restricted to localhost"

evaluate_check "NETWORK-IPV4" "UDP Ports 123, 161, 162, 5353 Open (IPv4)" "netstat -lnup | awk '\$1 == \"udp\" && \$4 ~ /:(123|161|162|5353)\$/ && \$4 !~ /^127\\./ { print \$4 }'" "^\s*$" "warning" "UDP Ports 123 (NTP), UDP ports 161 (SNMP), 162 (Trap), or 5353 (mDNS) are exposed on IPv4 — may leak device or service data"

evaluate_check "NETWORK-IPV4" "Potentially Vulnerable UDP Ports (IPv4)" "netstat -lnup | awk '\$1 == \"udp\" && \$4 ~ /:(69|1900|500|4500|520)\$/ && \$4 !~ /^127\\./ { print \$4 }'" "^\s*$" "critical" "One or more UDP ports (e.g., 69/TFTP, 1900/SSDP, 67/68/DHCP) are exposed on IPv4 — potentially vulnerable services detected"

#evaluate_check "NETWORK-IPV6" "Open IPv6 Ports" "netstat -tuln | grep '::'" "^$" "critical" "No open IPv6 ports should be exposed"

evaluate_check "NETWORK-IPV6" "All Active TCP Connections (IPv6, excluding ::1)" "netstat -ntp | awk '\$1 == \"tcp6\" && \$4 !~ /::1/ { print \$0 }'" "^\s*$" "info" "Displays all active IPv6 TCP connections (including LISTEN/ESTABLISHED) that are not bound to loopback (::1)"

evaluate_check "NETWORK-IPV6" "Common TCP Ports Exposed (IPv6, Warning)" "netstat -lnpt | awk '\$1 == \"tcp6\" && \$6 == \"LISTEN\" && \$4 ~ /:((53)|(80)|(25)|(110)|(143)|(465)|(587)|(993)|(995)|(8080)|(8443)|(22))$/ && \$4 !~ /::1/'" "^\s*$" "warning" "One or more common TCP ports are externally accessible on IPv6 — review exposure"

evaluate_check "NETWORK-IPV6" "Expanded Critical TCP Ports (excluding SSH) Listening or External (IPv6)" "netstat -lnpt | awk '\$1 == \"tcp6\" && \$6 == \"LISTEN\" && \$4 ~ /:((21)|(23)|(25)|(445)|(3306)|(5432)|(5900)|(5901)|(3389)|(5555)|(4444)|(8080)|(8443)|(41795))$/ && \$4 !~ /::1/'" "^\s*$" "critical" "One or more critical TCP ports (excluding SSH) are open or externally connected (IPv6) — review exposure"

evaluate_check "NETWORK-IPV6" "Open UDP Ports (IPv6, excluding localhost)" "netstat -lnup | awk '\$1 == \"udp6\" && \$4 !~ /::1/'" "^\s*$" "info" "Open UDP ports (IPv6) found that are not restricted to localhost (::1)"

evaluate_check "NETWORK-IPV6" "UDP Ports 123, 161, 162, 5353 Open (IPv6)" "netstat -lnup | awk '\$1 == \"udp6\" && \$4 ~ /:(123|161|162|5353)\$/ && \$4 !~ /::1/ { print \$4 }'" "^\s*$" "warning" "UDP Ports 123 (NTP), UDP ports 161 (SNMP), 162 (Trap), or 5353 (mDNS) are exposed on IPv6 — may leak device or service data"

evaluate_check "NETWORK-IPV6" "Potentially Vulnerable UDP Ports (IPv6)" "netstat -lnup | awk '\$1 == \"udp6\" && \$4 ~ /:(69|1900|500|4500|520)\$/ && \$4 !~ /::1/ { print \$4 }'" "^\s*$" "critical" "One or more UDP ports (e.g., 69/TFTP, 1900/SSDP) are exposed on IPv6 — potentially vulnerable services detected"
evaluate_check "NETWORK" "DNS Servers" "getprop net.dns1" ".*" "info" "Check DNS configs"
evaluate_check "NETWORK" "User Certs" "ls /data/misc/user/0/cacerts-added/ | wc -l" "^0$" "warning" "Certs could bypass pinning"
evaluate_check "NETWORK" "World-Writable Files" "find /data -type f \( -perm -o+w \) -exec ls -l {} \; 2>/dev/null | wc -l" "^0$" "critical" "Unprotected sensitive files"
evaluate_check "NETWORK" "Wi-Fi Security (WPA3)" "dumpsys wifi | grep 'WPA3-'" "WPA3" "warning" "WPA3 should be preferred over WPA2 for stronger Wi-Fi security"
evaluate_check "NETWORK" "DNS-over-TLS Enabled" "settings get global private_dns_mode" "hostname" "info" "DNS-over-TLS (DoT) should be enabled for encrypted DNS"
evaluate_check "NETWORK" "ARP Table Dump" "cat /proc/net/arp" ".*" "info" "Lists resolved ARP IP-MAC mappings"
evaluate_check "NETWORK" "Proxy Configuration" "settings get global http_proxy" "^$" "warning" "Proxy set may indicate MITM or forced redirection"
evaluate_check "NETWORK" "Captive Portal Detection" "settings get global captive_portal_mode" "^1$" "warning" "Should be 1 (default); 0 disables captive portal checks"


# ADDITIONAL SECURITY
evaluate_check "ADDITIONAL SECURITY" "Play Protect" "settings get secure package_verifier_enable" "^1$" "warning" "Play Protect should be enabled"
evaluate_check "ADDITIONAL SECURITY" "Security Patch Level" "getprop ro.build.version.security_patch" "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" "info" "Check for latest Android patch level"
evaluate_check "ADDITIONAL SECURITY" "Keyguard Timeout" "settings get secure lock_screen_lock_after_timeout" ".*" "info" "Time delay before screen locks"
evaluate_check "ADDITIONAL SECURITY" "Third-Party App Stores" "pm list packages | grep -E 'amazon|aptoide|getjar'" "^$" "warning" "Avoid non-Google app stores"
evaluate_check "ADDITIONAL SECURITY" "User-installed Apps" "pm list packages -3 | wc -l" ".*" "info" "Check how many user apps installed"
evaluate_check "ADDITIONAL SECURITY" "Logcat Access" "getprop ro.debuggable" "^0$" "critical" "Only system should access logs"
evaluate_check "ADDITIONAL SECURITY" "Unusual Files in /sdcard/" "ls /sdcard/ | grep -Ei '(key|creds|dump|log|backup)'" "^$" "warning" "Sensitive files in user-accessible storage"
evaluate_check "ADDITIONAL SECURITY" "Wi-Fi SSID" "dumpsys netstats | grep -i 'iface=wlan0'" ".*" "info" "Shows current Wi-Fi network"
evaluate_check "ADDITIONAL SECURITY" "Zygote Process Check" "ps | grep zygote" "zygote" "critical" "Zygote process is core to Android app lifecycle"
evaluate_check "INPUT SECURITY" "No 3rd party keyboards installed" "ime list -a" "no 3rd party" "medium" "Only system keyboards must be installed"

# APP & SYSTEM INTEGRITY & STORAGE & LOGS
evaluate_check "APP & SYSTEM INTEGRITY" "AppOps: private-data access" "dumpsys appops | grep -E 'READ_EXTERNAL_STORAGE|ACCESS_FINE_LOCATION'" "mode=ignore" "safe" "Monitor unexpected accesses to sensitive data"
evaluate_check "APP & SYSTEM INTEGRITY" "Security Tools Detected" "pm list packages | grep -E 'org.mobsf|com.offsec.nethunter|de.robv.android.xposed'" "^$" "warning" "Pentest frameworks or hacking tools found"
evaluate_check "APP & SYSTEM INTEGRITY" "Custom CAs Installed" "ls /data/misc/user/0/cacerts-added/ | wc -l" "^0$" "warning" "Custom certs may bypass pinning"
evaluate_check "APP & SYSTEM INTEGRITY" "APK Signature Path Check" "pm list packages -f | grep .apk | head -n 1" "package:" "info" "Checks for valid APK path info"
evaluate_check "STORAGE" "Hidden or Extra Partitions" "cat /proc/partitions | grep -Ev 'mmcblk0p[0-9]+|sda[0-9]+'" "^$" "info" "Detects non-standard or extra partitions"
evaluate_check "STORAGE" "SDCard Mount RW" "mount | grep /sdcard | grep rw" "^$" "warning" "SDCard should not be mounted read-write in restricted environments"
evaluate_check "STORAGE" "Orphaned Files in /data" "find /data -type f -uid 0 ! -user system 2>/dev/null | wc -l" "^0$" "info" "Looks for files owned by root but not by 'system' user"
evaluate_check "LOGS" "Recent Kernel Crashes" "dmesg | grep -iE 'fatal|panic|oops|BUG:' | tail -n 5" "^$" "info" "Recent kernel panics or fatal errors"
evaluate_check "LOGS" "Application Crash Log" "logcat -d -b crash | head -n 10" "^$" "info" "Recent app crash logs (look for repeated exceptions)"
evaluate_check "LOGS" "SELinux AVC Denials" "dmesg | grep 'avc:  denied'" "^$" "warning" "Check for any denied SELinux actions"

# === ADVANCED CHECKS ===

# KERNEL & SYSTEM & Trusted Security Modules
evaluate_check "SYSTEM" "Kernel Version" "uname -r" ".*" "info" "Kernel build/version details"
evaluate_check "SYSTEM" "Audit Logs Enabled" "cat /proc/sys/kernel/printk" ".*" "warning" "Non-zero values indicate audit logs may be active"
evaluate_check "SYSTEM" "ASLR Enabled" "cat /proc/sys/kernel/randomize_va_space" "2" "critical" "ASLR must be enabled (value 2) to randomize memory layout and protect against memory-based attacks."
evaluate_check "SYSTEM" "KASLR Enabled" "dmesg | grep -i kaslr" ".*enabled.*" "critical" "Kernel Address Space Layout Randomization (KASLR) should be enabled to randomize kernel memory layout."
evaluate_check "SYSTEM" "NX (No eXecute) Bit Enabled" "dmesg | grep -i NX" ".*NX.*protection.*" "critical" "NX bit must be enabled to prevent execution of code in data memory regions."
evaluate_check "SYSTEM" "Core Dumps Disabled" "cat /proc/sys/kernel/core_pattern" "|/dev/null" "high" "Core dumps should be disabled to prevent sensitive data leakage."
evaluate_check "SYSTEM" "SECCOMP Enabled" "zcat /proc/config.gz | grep CONFIG_SECCOMP=" "CONFIG_SECCOMP=Y" "high" "SECCOMP must be enabled to restrict the system calls available to applications."
evaluate_check "SYSTEM" "Kernel Modules Loading Restricted" "cat /proc/sys/kernel/modules_disabled" "1" "high" "Kernel module loading should be disabled after boot to prevent unauthorized module insertion."
evaluate_check "SYSTEM" "Protected Symlinks Enabled" "cat /proc/sys/fs/protected_symlinks" "1" "medium" "Symlink protection should be enabled to prevent symlink-based privilege escalation."
evaluate_check "SYSTEM" "Protected Hardlinks Enabled" "cat /proc/sys/fs/protected_hardlinks" "1" "medium" "Hardlink protection should be enabled to prevent unauthorized file access."
evaluate_check "SYSTEM" "dmesg Restriction Enabled" "cat /proc/sys/kernel/dmesg_restrict" "1" "medium" "Restricting dmesg access prevents unprivileged users from reading kernel logs."
evaluate_check "SYSTEM" "Audit Logs Enabled" "cat /proc/sys/kernel/printk" ".*" "warning" "Non-zero printk values may indicate that audit logs are active. Review logging configuration."
evaluate_check "MEMORY" "Stack Canaries" "zcat /proc/config.gz | grep CONFIG_CC_STACKPROTECTOR_STRONG" "CONFIG_CC_STACKPROTECTOR_STRONG=y" "critical" "Stack canaries should be enabled to prevent buffer overflows"
evaluate_check "MEMORY" "ROP Mitigation (PAC)" "zcat /proc/config.gz | grep CONFIG_ARM64_PTR_AUTH" "CONFIG_ARM64_PTR_AUTH=y" "critical" "Pointer Authentication (PAC) should be enabled to prevent ROP attacks"
evaluate_check "MEMORY" "Memory Tagging (MTE)" "zcat /proc/config.gz | grep CONFIG_ARM64_MTE" "CONFIG_ARM64_MTE=y" "critical" "Memory Tagging Extension (MTE) should be enabled for JIT hardening"
evaluate_check "KERNEL" "Kernel Hardening (PAN/UAO)" "zcat /proc/config.gz | grep -E 'CONFIG_ARM64_PAN=|CONFIG_ARM64_UAO='" "CONFIG_ARM64_PAN=y.*CONFIG_ARM64_UAO=y" "critical" "Privileged Access Never (PAN) and User Access Override (UAO) should be enabled for memory protection"
evaluate_check "KERNEL" "Kernel Pointer Leaking" "cat /proc/sys/kernel/kptr_restrict" "2" "high" "Kernel pointers should not be exposed (2 = full restriction)"
evaluate_check "SELinux" "SELinux Denials" "dmesg | grep 'avc:  denied'" "^$" "warning" "Check for SELinux policy violations"
evaluate_check "TEE/TPM" "TEE Driver Presence" "ls /dev/tee* /dev/teepriv* 2>/dev/null" "^ls:.*No such file or directory$" "warning" "TEE driver (Trusted Execution Environment) should exist on modern secure devices"
evaluate_check "TEE/TPM" "TPM Keystore Presence" "ls /system/lib64/hw/keystore.* 2>/dev/null" "^ls:.*No such file or directory$" "info" "Checks for hardware-backed keystore modules"
evaluate_check "TEE/TPM" "TEE Vendor Prop" "getprop | grep -i tee" ".*" "info" "Shows any TEE-related properties"
evaluate_check "INTEGRITY" "Test-keys Build" "getprop ro.build.fingerprint" "release-keys" "critical" "Test-keys in fingerprint indicates insecure engineering/debug build"
evaluate_check "INTEGRITY" "Boot Image Tampered" "ls -l /init /init.rc" ".*" "info" "Check for unusual file sizes or dates"
evaluate_check "INTEGRITY" "System Partition Tampering" "lsattr /system/bin/app_process* 2>/dev/null" ".*" "info" "Detects immutability or possible tampering"
evaluate_check "PATCHING" "Security Patch Age" "getprop ro.build.version.security_patch" "^[0-9]{4}-[0-9]{2}-[0-9]{2}$" "warning" "Compare patch date to current date (flag >90 days as critical manually)"
evaluate_check "PATCHING" "OTA Update Path" "getprop ro.build.version.incremental" ".*" "info" "OTA incremental version for build tracking"


# PACKAGE AUDIT
evaluate_check "APPS & RUNTIME" "Frida Detected" "pm list packages | grep frida" "^$" "critical" "Frida binary indicates runtime manipulation"
evaluate_check "APPS & RUNTIME" "Magisk Detected" "pm list packages | grep magisk" "^$" "critical" "Magisk can hide root access"
evaluate_check "APPS & RUNTIME" "Xposed Framework" "pm list packages | grep xposed" "^$" "critical" "Xposed framework enables deep system tweaks"
evaluate_check "APPS & RUNTIME" "Unapproved APKs in /data/local/tmp" "ls /data/local/tmp/*.apk" "^ls:.*No such file or directory$" "warning" "Unauthorized sideloading or testing APKs"
evaluate_check "APPS" "Debuggable Apps (Strict)" "pm list packages -d | grep -v 'com.android'" "^$" "critical" "No non-system apps should be debuggable"
evaluate_check "APPS" "APK Signature Verification" "dumpsys package verification | grep 'verified=true'" "verified=true" "critical" "APK signatures must be verified"
evaluate_check "APPS" "Dynamic Code Loading" "pm list packages | grep -E 'dexopt|dynamic'" "^$" "warning" "Apps should not use dynamic code loading (security risk)"

# ROOT TRACE
evaluate_check "ROOT TRACE" "Magisk Binary Presence" "ls /sbin | grep magisk" "^$" "critical" "Indicates root hiding tools like Magisk are installed"
evaluate_check "ROOT TRACE" "su Binary in Common Paths" "ls /system/xbin/su /system/bin/su 2>/dev/null" "^ls:.*No such file or directory$" "critical" "su binary indicates rooted device"

# FILESYSTEM & MOUNTS & STORAGE
evaluate_check "FILESYSTEM" "Mount Points (rw/ro)" "mount | grep -E ' rw| ro'" ".*" "info" "Review mounted partitions and access permissions"
evaluate_check "FILESYSTEM" "tmpfs Usage" "mount | grep tmpfs" ".*" "info" "Shows use of temporary memory file system"
evaluate_check "STORAGE" "External Storage Encryption" "getprop ro.crypto.volume.filenames_mode" "aes-256-cts" "warning" "External storage filenames should be encrypted"
evaluate_check "FILESYSTEM" "World-Readable Files" "find /data -type f -perm -o+r -exec ls -l {} \; 2>/dev/null | wc -l" "^0$" "critical" "No sensitive files should be world-readable"
evaluate_check "FILESYSTEM" "SQLite DB Permissions" "find /data/data -name '*.db' -exec ls -l {} \; 2>/dev/null | grep -v 'rw-------'" "^$" "warning" "SQLite databases should not be world-readable/writable"

# ADB SECURITY
evaluate_check "ADB SECURITY" "ADB Keys Present" "ls /data/misc/adb/adb_keys" "^ls:.*No such file or directory$" "warning" "Presence of adb_keys may indicate previously trusted host"
evaluate_check "ADB TRUST" "ADB Over Network Port" "getprop service.adb.tcp.port" "^$" "safe" "Should be empty or disabled; non-default = risk"
evaluate_check "DEBUGGING" "System Debug Binaries" "ls /system/bin/gdbserver /system/bin/strace 2>/dev/null" "^ls:.*No such file or directory$" "warning" "Presence of debug tools increases attack surface"

# PROCESS SNAPSHOT
evaluate_check "PROCESS SNAPSHOT" "Top 5 Running Processes" "ps | head -n 5" ".*" "info" "Initial list of active processes"


# ============================================== #
# VULNERABILITY CHECKS                           #
# ============================================== #

evaluate_check "PATH ABUSE" "Writable Paths in \$PATH" "echo \$PATH | tr ':' '\n' | xargs -I{} sh -c 'test -w {} && echo {}'" "^$" "critical" "Writable dirs in PATH can lead to privilege escalation"


# MALWARE CHECKS
evaluate_check "MALWARE SCAN" "Suspicious Packages" "pm list packages | grep -Ei 'spy|inject|keylog|steal|remote|sms|trojan'" "^$" "critical" "Flag suspicious package names"
evaluate_check "MALWARE SCAN" "Temp APKs in /data/local/tmp" "ls /data/local/tmp/*.apk" "^ls:.*No such file or directory$" "warning" "Hidden payloads or test malware"
evaluate_check "MALWARE & SENSITIVE DATA SCAN" "Sensitive/Malicious Files (Recursive)" "find /sdcard/ -type f -iregex '.*\(key\|creds\|dump\|log\|backup\|conf\|config\|token\|password\|secret\|payload\|exploit\|malware\|trojan\|root\|hack\|shell\|spy\|\.apk\|\.dex\|\.so\|\.elf\|\.sh\|\.exe\|\.bat\)$'" "^$" "warning" "Finds files on external storage commonly linked to leaks or malware (recursively)."
evaluate_check "MALWARE SCAN" "Non-System Apps Count" "pm list packages -3 | wc -l" ".*" "info" "Apps installed outside system image"

# Additional CHECKS CIS 
evaluate_check "CHECKS CIS" "USB File Transfer Disabled" "settings get global usb_mass_storage_enabled 2>/dev/null" "^0$" "warning" "Should be disabled to block unauthorized USB file access"
evaluate_check "CHECKS CIS" "Development Settings Disabled" "settings get global development_settings_enabled 2>/dev/null" "^0$" "warning" "Developer mode should be disabled for production devices"
evaluate_check "CHECKS CIS" "Wi-Fi Direct Disabled (WFD)" "pm list packages 2>/dev/null | grep -i wfd" "^$" "warning" "Wi-Fi Direct (WFD) package should be removed if unused"
evaluate_check "CHECKS CIS" "Auto System Update Enabled" "settings get global auto_update_system 2>/dev/null" "^1$" "info" "Auto updates improve patch consistency"
evaluate_check "CHECKS CIS" "Credential Storage Cleared" "ls /data/misc/keystore/user_0 2>&1" "No such file or directory" "info" "No residual user credential files"

# ============================================== #
# BLUETOOTH SECURITY CHECKS (NIST COMPLIANT)     #
# ============================================== #

evaluate_check "BLUETOOTH" "Bluetooth Enabled" "settings get global bluetooth_on" "^0$" "warning" "NIST recommends disabling Bluetooth when not in use (SC-8)"
evaluate_check "BLUETOOTH" "Discoverable Mode" "settings get global bluetooth_discoverability" "^0$" "critical" "Device should not be discoverable (AC-18)"
evaluate_check "BLUETOOTH" "Secure Pairing Mode" "dumpsys bluetooth_manager | grep 'Pairing mode:'" "Pairing mode:.*Secure" "critical" "Only secure pairing modes should be allowed (NIST IA-2)"
evaluate_check "BLUETOOTH" "Bluetooth Encryption" "dumpsys bluetooth_manager | grep 'Encryption:'" "Encryption:.*Enabled" "critical" "Bluetooth encryption must be enabled (SC-13)"
evaluate_check "BLUETOOTH" "Authentication Required" "dumpsys bluetooth_manager | grep 'Authentication:'" "Authentication:.*Required" "critical" "Authentication must be required for pairing (IA-2)"
evaluate_check "BLUETOOTH" "MAC Randomization" "settings get secure bluetooth_address | grep -E '([0-9A-F]{2}:){5}[0-9A-F]{2}'" "^$" "warning" "Static MAC addresses should be avoided (SC-8(1))"
evaluate_check "BLUETOOTH" "Paired Devices Count" "dumpsys bluetooth_manager | grep 'Bonded devices:' -A 10 | grep 'Device:' | wc -l" "^0$" "warning" "Review all paired devices (AC-3)"
evaluate_check "BLUETOOTH" "HCI Snoop Logging" "settings get secure bluetooth_hci_log" "^0$" "info" "HCI logging should be disabled in production (AU-12)"
evaluate_check "BLUETOOTH" "Unnecessary Profiles" "dumpsys bluetooth_manager | grep 'Profile:' | grep -vE 'A2DP|HFP|HSP'" "^$" "warning" "Disable unused profiles (CM-7)"
evaluate_check "BLUETOOTH" "LE Security Mode" "dumpsys bluetooth_manager | grep 'LE Security Mode:'" "LE Security Mode: [2-4]" "critical" "LE should use Mode 2 (Secure Connections) or higher (SC-13)"
evaluate_check "BLUETOOTH" "Bluetooth Version" "getprop ro.bluetooth.version" "^[5-9]|[1-9][0-9]" "info" "Bluetooth version should be 5.0 or newer for enhanced security features (SC-13)"
evaluate_check "BLUETOOTH" "Just Works Pairing" "dumpsys bluetooth_manager | grep -i 'Just Works'" "^$" "critical" "Just Works insecure pairing method should not be enabled (IA-2)"
evaluate_check "BLUETOOTH" "Link Key Strength" "dumpsys bluetooth_manager | grep -i 'Key Length'" "128" "critical" "Link encryption key length must be at least 128 bits (IA-5)"
evaluate_check "BLUETOOTH" "Bluetooth Debugging Interface" "dumpsys bluetooth_manager | grep -i 'Debug.*true'" "^$" "critical" "Bluetooth debugging interfaces must be disabled in production (CM-6)"
evaluate_check "BLUETOOTH" "Secure Simple Pairing (SSP)" "dumpsys bluetooth_manager 2>/dev/null | grep -iq 'Secure Simple Pairing.*Enabled' && echo Enabled || echo Disabled" "Enabled" "critical" "Checks if SSP is enabled (downgrade attacks like KNOB are prevented)."
evaluate_check "BLUETOOTH" "Bluedroid Stack Active" "[ \"\$(getprop ro.bluetooth.stack 2>/dev/null | grep -i bluedroid)\" ] && echo VULNERABLE || echo SAFE" "SAFE" "critical" "Detects if Bluedroid stack is active (BlueBorne vulnerable; upgrade to Fluoride recommended)."
evaluate_check "BLUETOOTH" "Bluetooth Firmware Files" "ls /vendor/firmware/bluetooth* /system/etc/firmware/bluetooth* 2>/dev/null | wc -l" "^[1-9][0-9]*$" "warning" "Checks for signed Bluetooth firmware blobs (missing may mean tampering or custom build)."
evaluate_check "BLUETOOTH" "Raw Radio Device Nodes" "ls /dev/radio* /dev/hci* 2>/dev/null | wc -l" "^0$" "critical" "Exposes low-level radio nodes. Presence may indicate increased attack surface."
evaluate_check "BLUETOOTH" "bluetoothd Hardening" "(ps -A -o cmd 2>/dev/null | grep -E 'bluetoothd|bluetooth' | grep -q -- '-n') && echo HARDENED || echo UNPROTECTED" "HARDENED" "warning" "Checks if the Bluetooth daemon runs in hardened (no-privilege) mode."
evaluate_check "BLUETOOTH" "BR/EDR Secure Connections" "settings get global bluetooth_br_edr_secure_connections 2>/dev/null | grep -q '^1$' && echo Enforced || echo NotEnforced" "Enforced" "critical" "Should return 'Enforced' to guarantee strong encryption (prevents KNOB attack)."
evaluate_check "BLUETOOTH" "SELinux Bluetooth Policy" "(ls -Z /system/bin/bluetooth* 2>/dev/null | grep -q 'bluetooth:s0') && echo RESTRICTIVE || echo PERMISSIVE" "RESTRICTIVE" "warning" "SELinux domain for Bluetooth should be restrictive to prevent privilege escalation."
evaluate_check "BLUETOOTH" "BLE MAC Randomization" "VAR=\$(settings get global bluetooth_address_rotation_enabled 2>/dev/null); if [ -z \"\$VAR\" ]; then echo NotSupported; elif [ \"\$VAR\" = \"1\" ]; then echo Enabled; else echo Disabled; fi" "Enabled" "info" "Should be enabled to randomize BLE MAC (prevents device tracking/leakage)."
evaluate_check "BLUETOOTH" "Legacy Bluetooth Profiles" "dumpsys bluetooth_manager | grep -E 'OBEX|PAN|SAP'" "^$" "warning" "Legacy profiles can expose device to known CVEs—disable if not needed."
evaluate_check "BLUETOOTH" "Custom Vendor Bluetooth Binaries" "ls /vendor/lib*/hw/bluetooth* /system/lib*/hw/bluetooth* 2>/dev/null | wc -l" "^[1-9][0-9]*$" "info" "Lists vendor or custom Bluetooth libraries (review for supply chain risk)."
evaluate_check "BLUETOOTH" "Bluetooth Stack Version" "dumpsys package com.android.bluetooth | grep versionName" ".*" "info" "Review the version of the Bluetooth stack package."
evaluate_check "BLUETOOTH" "Bluetooth Service Crashes" "logcat -d -b crash | grep -i bluetooth | tail -n 5" "^$" "info" "Recent crashes in Bluetooth stack may indicate exploits or instability."
evaluate_check "BLUETOOTH" "Scan Always Available" "settings get global ble_scan_always_enabled" "^0$" "warning" "Should be disabled to prevent background BLE scanning (privacy risk)."
evaluate_check "BLUETOOTH" "Apps with BLUETOOTH Permission" "pm list permissions -g -d | grep -A1 'BLUETOOTH$' | grep -c 'package:'" "^[1-3]$" "warning" "Too many apps with BLUETOOTH permission increases risk."
evaluate_check "BLUETOOTH" "Bluetooth Debug Properties" "getprop | grep -i bluetooth | grep -i debug" "^$" "info" "Debug properties for Bluetooth should not be set on production."

# Close the HTML file
cat <<EOF >> "$html_file"
  <script>
    // Finalize the auditData array
    window.auditData = JSON.parse(\`[\${window.auditDataRaw}]\`);
    
    // Initialize the report
    document.addEventListener('DOMContentLoaded', function() {
      renderFindings();
      updateSummaryCounts();
      renderCharts();
      setupSearch();
    });
  </script>
</body>
</html>
EOF

# Final CLI summary
echo -e "\n======================================"
echo "ANDROID AUDIT COMPLETED"
echo "Safe Checks    : $safe_count"
echo "Warnings       : $warning_count"
echo "Critical Issues: $critical_count"
echo "Info Items     : $info_count"
echo "TXT Report     : $txt_file"
echo "HTML Report    : $html_file"
echo "======================================"
