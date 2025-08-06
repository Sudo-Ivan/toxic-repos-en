class ToxicReposSearch {
    constructor() {
        this.data = [];
        this.filteredData = [];
        this.currentDataSource = 'translated';
        this.currentPage = 0;
        this.itemsPerPage = 20;
        
        this.initializeElements();
        this.bindEvents();
        this.loadData();
    }
    
    initializeElements() {
        this.searchInput = document.getElementById('searchInput');
        this.searchBtn = document.getElementById('searchBtn');
        this.problemTypeFilter = document.getElementById('problemTypeFilter');
        this.dateFilter = document.getElementById('dateFilter');
        this.clearFiltersBtn = document.getElementById('clearFilters');
        this.totalCount = document.getElementById('totalCount');
        this.filteredCount = document.getElementById('filteredCount');
        this.loadingIndicator = document.getElementById('loadingIndicator');
        this.errorMessage = document.getElementById('errorMessage');
        this.results = document.getElementById('results');
        this.dataSourceRadios = document.querySelectorAll('input[name="dataSource"]');
        this.loadMoreBtn = document.getElementById('loadMoreBtn');
        this.loadMoreContainer = document.getElementById('loadMoreContainer');
        this.exportBtn = document.getElementById('exportBtn');
        this.exportMenu = document.getElementById('exportMenu');
    }
    
    bindEvents() {
        this.searchBtn.addEventListener('click', () => this.performSearch());
        this.searchInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.performSearch();
        });
        this.searchInput.addEventListener('input', () => this.performSearch());
        
        this.problemTypeFilter.addEventListener('change', () => this.performSearch());
        this.dateFilter.addEventListener('change', () => this.performSearch());
        this.clearFiltersBtn.addEventListener('click', () => this.clearFilters());
        
        this.dataSourceRadios.forEach(radio => {
            radio.addEventListener('change', (e) => {
                this.currentDataSource = e.target.value;
                this.loadData();
            });
        });
        
        this.loadMoreBtn.addEventListener('click', () => this.loadMore());
        
        // Export functionality
        document.querySelectorAll('.export-option').forEach(option => {
            option.addEventListener('click', (e) => {
                e.preventDefault();
                const format = e.target.dataset.format;
                this.exportData(format);
            });
        });
        
        // Close export menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!e.target.closest('.export-dropdown')) {
                this.exportMenu.style.display = 'none';
            }
        });
        
        // Toggle export menu
        this.exportBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            this.exportMenu.style.display = this.exportMenu.style.display === 'block' ? 'none' : 'block';
        });
    }
    
    async loadData() {
        this.showLoading(true);
        this.hideError();
        
        try {
            const baseUrl = 'https://raw.githubusercontent.com/Sudo-Ivan/toxic-repos-en/main';
            const csvPath = this.currentDataSource === 'original' 
                ? `${baseUrl}/data/csv/toxic-repos.csv`
                : `${baseUrl}/data-en/csv/toxic-repos.csv`;
                
            const response = await fetch(csvPath);
            if (!response.ok) {
                throw new Error(`Failed to load data: ${response.statusText}`);
            }
            
            const csvText = await response.text();
            this.data = this.parseCSV(csvText);
            this.updateStats();
            this.performSearch();
            
        } catch (error) {
            this.showError(`Error loading data: ${error.message}`);
            console.error('Error loading data:', error);
        } finally {
            this.showLoading(false);
        }
    }
    
    parseCSV(csvText) {
        const lines = csvText.trim().split('\n');
        const headers = lines[0].split(',');
        
        return lines.slice(1).map(line => {
            const values = this.parseCSVLine(line);
            const record = {};
            
            headers.forEach((header, index) => {
                record[header.trim()] = values[index] ? values[index].trim().replace(/^"|"$/g, '') : '';
            });
            
            return record;
        }).filter(record => record.id && record.name);
    }
    
    parseCSVLine(line) {
        const result = [];
        let current = '';
        let inQuotes = false;
        
        for (let i = 0; i < line.length; i++) {
            const char = line[i];
            
            if (char === '"') {
                inQuotes = !inQuotes;
            } else if (char === ',' && !inQuotes) {
                result.push(current);
                current = '';
            } else {
                current += char;
            }
        }
        
        result.push(current);
        return result;
    }
    
    performSearch() {
        const searchTerm = this.searchInput.value.toLowerCase().trim();
        const problemType = this.problemTypeFilter.value;
        const dateFilter = this.dateFilter.value;
        
        this.filteredData = this.data.filter(record => {
            const matchesSearch = !searchTerm || 
                record.name.toLowerCase().includes(searchTerm) ||
                record.description.toLowerCase().includes(searchTerm) ||
                record.problem_type.toLowerCase().includes(searchTerm);
            
            const matchesProblemType = !problemType || record.problem_type === problemType;
            
            const matchesDate = !dateFilter || record.datetime.startsWith(dateFilter);
            
            return matchesSearch && matchesProblemType && matchesDate;
        });
        
        this.currentPage = 0;
        this.updateStats();
        this.renderResults();
    }
    
    clearFilters() {
        this.searchInput.value = '';
        this.problemTypeFilter.value = '';
        this.dateFilter.value = '';
        this.performSearch();
    }
    
    updateStats() {
        this.totalCount.textContent = this.data.length.toLocaleString();
        this.filteredCount.textContent = this.filteredData.length.toLocaleString();
    }
    
    renderResults() {
        if (this.filteredData.length === 0) {
            this.results.textContent = '';
            const noResults = document.createElement('div');
            noResults.className = 'no-results';
            noResults.textContent = 'No results found. Try adjusting your search criteria.';
            this.results.appendChild(noResults);
            this.loadMoreContainer.classList.add('hidden');
            return;
        }
        
        const startIndex = 0;
        const endIndex = Math.min(this.itemsPerPage, this.filteredData.length);
        const currentData = this.filteredData.slice(startIndex, endIndex);
        
        this.results.textContent = '';
        currentData.forEach(record => {
            const cardElement = this.createResultCardElement(record);
            this.results.appendChild(cardElement);
        });
        
        // Show/hide load more button
        if (this.filteredData.length > this.itemsPerPage) {
            this.loadMoreContainer.classList.remove('hidden');
            this.loadMoreBtn.disabled = false;
        } else {
            this.loadMoreContainer.classList.add('hidden');
        }
    }
    
    loadMore() {
        this.currentPage++;
        const startIndex = this.currentPage * this.itemsPerPage;
        const endIndex = Math.min(startIndex + this.itemsPerPage, this.filteredData.length);
        const additionalData = this.filteredData.slice(startIndex, endIndex);
        
        if (additionalData.length > 0) {
            additionalData.forEach(record => {
                const cardElement = this.createResultCardElement(record);
                this.results.appendChild(cardElement);
            });
        }
        
        // Hide load more button if no more data
        if (endIndex >= this.filteredData.length) {
            this.loadMoreBtn.disabled = true;
            this.loadMoreBtn.textContent = 'No More Results';
        }
    }
    
    createResultCardElement(record) {
        const date = new Date(record.datetime).toLocaleDateString();
        const problemType = record.problem_type || 'unknown';
        
        const card = document.createElement('div');
        card.className = 'result-card';
        
        const header = document.createElement('div');
        header.className = 'result-header';
        
        const headerContent = document.createElement('div');
        
        const name = document.createElement('div');
        name.className = 'result-name';
        name.textContent = record.name;
        
        const type = document.createElement('div');
        type.className = `result-type ${problemType}`;
        type.textContent = problemType.replace('_', ' ');
        
        headerContent.appendChild(name);
        headerContent.appendChild(type);
        header.appendChild(headerContent);
        
        const description = document.createElement('div');
        description.className = 'result-description';
        description.textContent = record.description || 'No description available';
        
        const footer = document.createElement('div');
        footer.className = 'result-footer';
        
        const dateDiv = document.createElement('div');
        dateDiv.className = 'result-date';
        dateDiv.textContent = date;
        footer.appendChild(dateDiv);
        
        if (record.commit_link) {
            const link = document.createElement('a');
            link.href = record.commit_link;
            link.target = '_blank';
            link.className = 'result-link';
            link.textContent = 'View Source';
            footer.appendChild(link);
        }
        
        card.appendChild(header);
        card.appendChild(description);
        card.appendChild(footer);
        
        return card;
    }
    
    createResultCard(record) {
        const date = new Date(record.datetime).toLocaleDateString();
        const problemType = record.problem_type || 'unknown';
        
        return `
            <div class="result-card">
                <div class="result-header">
                    <div>
                        <div class="result-name">${this.escapeHtml(record.name)}</div>
                        <div class="result-type ${this.escapeHtml(problemType)}">${this.escapeHtml(problemType.replace('_', ' '))}</div>
                    </div>
                </div>
                
                <div class="result-description">
                    ${this.escapeHtml(record.description) || 'No description available'}
                </div>
                
                <div class="result-footer">
                    <div class="result-date">${date}</div>
                    ${record.commit_link ? `<a href="${this.escapeHtml(record.commit_link)}" target="_blank" class="result-link">View Source</a>` : ''}
                </div>
            </div>
        `;
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
    
    showLoading(show) {
        this.loadingIndicator.classList.toggle('hidden', !show);
    }
    
    showError(message) {
        this.errorMessage.textContent = message;
        this.errorMessage.classList.remove('hidden');
    }
    
    hideError() {
        this.errorMessage.classList.add('hidden');
    }
    
    exportData(format) {
        const baseUrl = 'https://raw.githubusercontent.com/Sudo-Ivan/toxic-repos-en/main';
        let downloadUrl;
        let filename;
        
        switch (format) {
            case 'csv':
                downloadUrl = this.currentDataSource === 'original' 
                    ? `${baseUrl}/data/csv/toxic-repos.csv`
                    : `${baseUrl}/data-en/csv/toxic-repos.csv`;
                filename = `toxic-repos-${this.currentDataSource}.csv`;
                break;
            case 'json':
                downloadUrl = this.currentDataSource === 'original' 
                    ? `${baseUrl}/data/json/toxic-repos.json`
                    : `${baseUrl}/data-en/json/toxic-repos.json`;
                filename = `toxic-repos-${this.currentDataSource}.json`;
                break;
            case 'sqlite':
                downloadUrl = this.currentDataSource === 'original' 
                    ? `${baseUrl}/data/sqlite/toxic-repos.sqlite3`
                    : `${baseUrl}/data-en/sqlite/toxic-repos.sqlite3`;
                filename = `toxic-repos-${this.currentDataSource}.sqlite3`;
                break;
            default:
                return;
        }
        
        // Create download link
        const link = document.createElement('a');
        link.href = downloadUrl;
        link.download = filename;
        link.target = '_blank';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        
        // Close export menu
        this.exportMenu.style.display = 'none';
    }
}

document.addEventListener('DOMContentLoaded', () => {
    new ToxicReposSearch();
});