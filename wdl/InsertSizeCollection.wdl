version 1.0

import "Structs.wdl"

#################################################################################
####        Required basic arguments                                            #
#################################################################################
workflow InsertSizeCollection {

    meta {
        author: "Stephanie Hao"
        email: "shao@broadinstitute.org"
    }

    input {
    File bam_file
    File bam_index
    String subset_docker
    # Runtime configuration overrides
    RuntimeAttr? runtime_attr_samtools_view
    File reference_fasta
    File reference_index_file

    }

    call samtoolsViewInsertSize as collectInsertSize {
        input :
        bam_file=bam_file,
        bam_index=bam_index,
        reference_fasta=reference_fasta,
        reference_index_file=reference_index_file,
        runtime_attr_override = runtime_attr_samtools_view,
        subset_docker=subset_docker
    }

    output {
    File insertSize = collectInsertSize.output_insert_size
  }
}


task samtoolsViewInsertSize {
    input {
        File bam_file
        File bam_index
        String subset_docker
        File reference_fasta
        File reference_index_file
        RuntimeAttr? runtime_attr_override
    }
        
    Int num_cpu = if defined(runtime_attr_override) then select_first([select_first([runtime_attr_override]).cpu_cores, 4]) else 4
    Float disk_overhead = 10.0
    Float bam_size = size(bam_file, "GiB")
    Float ref_size = size(reference_fasta, "GiB")
    Float ref_index_size = size(reference_index_file, "GiB")
    Int vm_disk_size = ceil(bam_size + ref_size + ref_index_size + disk_overhead)
    
    String bam_file_name = basename(bam_file, ".bam")
    String outfile_name = "~{bam_file_name}_insert_size.txt"

    RuntimeAttr default_attr = object {
        cpu_cores: num_cpu,
        mem_gb: 1.5, 
        disk_gb: vm_disk_size,
        boot_disk_gb: 10,
        preemptible_tries: 3,
        max_retries: 1
    }
    RuntimeAttr runtime_attr = select_first([runtime_attr_override, default_attr])

    command <<<

        set -Eeuo pipefail
  
        # selecting columns for just insert size plot
        samtools view ~{bam_file} | awk '{print $1 "\t" $3 "\t" $4 "\t" $8 "\t" $9}' > ~{outfile_name}
    
    >>>

    output {
        File output_insert_size = "~{outfile_name}"
    }

    runtime {
        cpu: select_first([runtime_attr.cpu_cores, default_attr.cpu_cores])
        memory: select_first([runtime_attr.mem_gb, default_attr.mem_gb]) + " GiB"
        disks: "local-disk " + select_first([runtime_attr.disk_gb, default_attr.disk_gb]) + " HDD"
        bootDiskSizeGb: select_first([runtime_attr.boot_disk_gb, default_attr.boot_disk_gb])
        docker: subset_docker
        preemptible: select_first([runtime_attr.preemptible_tries, default_attr.preemptible_tries])
        maxRetries: select_first([runtime_attr.max_retries, default_attr.max_retries])
    }
}
