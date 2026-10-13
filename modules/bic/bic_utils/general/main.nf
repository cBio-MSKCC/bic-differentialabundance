
def getFullConditionList() {
    def inputFile = file(params.input, checkIfExists: true)
    def contrastFile = file(params.contrasts, checkIfExists: true)
    def cond_list = []
    def sample_list = []
    def variablesList = []
    def contrastsSeparator = params.contrasts.endsWith('tsv') ? '\t' : ','
    def inputSeparator = params.input.endsWith('tsv') ? '\t' : ','

    // Grab the column names of the conditions from variables column.
    contrastFile.withReader { reader ->
        def header = reader.readLine().split(contrastsSeparator)
        def variableIndex = header.findIndexOf { it == "variable" }
        
        if (variableIndex == -1) {
            error "variable column not found in contrast file"
        }

        reader.eachLine { line -> 
            def columns = line.split(contrastsSeparator)
            if(! variablesList.contains(columns[variableIndex])) {
                variablesList << columns[variableIndex]
            }
        }

    }
    // Variable list now has all the columns names we need to pull for conditions

    // Parse the file content
    inputFile.withReader { reader ->
        def header = reader.readLine().split(inputSeparator)
        def conditionIndexes = []

        def sampleIndex = header.findIndexOf { it == "sample" }
        if (sampleIndex == -1) {
            error "sample column not found in the input file"
        }

        // grab indexes of each comparison column from input header
        variablesList.each { var ->
            def tmpIndex = header.findIndexOf { it == var }
            if (tmpIndex == -1 ){
                error "condition variable not found in input header: $var"
            }
            conditionIndexes << tmpIndex
        }   

        // now add each comparison_condition to a condition list
        reader.eachLine { line ->
            def columns = line.split(inputSeparator)
            
            if (!sample_list.contains(columns[sampleIndex])) {
                conditionIndexes.each { idx ->
                    def condition = columns[idx]?.trim()
                    if (condition && condition != '_EXCLUDE_') {
                        cond_list << idx + "_" + condition
                    }
                }
            }
        }
    }
    return cond_list
}
