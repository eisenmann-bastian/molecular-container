params.input = 'greetings.csv'

process WRITE_GREETING {
    publishDir 'output', mode: 'copy'

    input:
    env 'GREETING'

    output:
    path 'greeting.txt'

    script:
    '''
    printf '%s\n' "$GREETING" > greeting.txt
    '''
}

process UPPERCASE_GREETING {
    publishDir 'output', mode: 'copy'

    input:
    path greeting_file

    output:
    path 'uppercase.txt'

    script:
    '''
    tr '[:lower:]' '[:upper:]' < greeting.txt > uppercase.txt
    '''
}

workflow {
    greetings = Channel.fromPath(params.input, checkIfExists: true)
        .splitCsv()
        .map { row -> row[0] }
    UPPERCASE_GREETING(WRITE_GREETING(greetings))
}
