version 1.0

import "Structs.wdl"

#################################################################################
####        Required basic arguments                                            #
#################################################################################
workflow SubsettingReads {

    meta {
        author: "Stephanie Hao"
        email: "shao@broadinstitute.org"
    }

    input {
    File bam_file
    File bam_index
    String subset_docker
    Int? lower_bound_length
    Int? upper_bound_length
    String? subset_output_name
    String? samtools_option
    File? reference_fasta
    File? reference_index_file

    # Runtime configuration overrides
    RuntimeAttr? runtime_attr_samtools_view

    }

    call samtoolsViewSubset as svs {
        input :
        bam_file=bam_file,
        bam_index=bam_index,
        subset_output_name=subset_output_name,
        reference_fasta=reference_fasta,
        reference_index_file=reference_index_file,
        runtime_attr_override = runtime_attr_samtools_view,
        subset_docker=subset_docker
    }

    output {
    File subset_bam_file = svs.output_bam_file
    File subset_bam_index = svs.output_bam_index
  }
}


task samtoolsViewSubset {
    input {
        File bam_file
        File bam_index
        Int? lower_bound_length = select_first([lower_bound_length, 147])
        Int? upper_bound_length = select_first([upper_bound_length, 155])
        String subset_docker
        String subset_output_name = select_first([subset_output_name, "subset"])
        File? reference_fasta
        File? reference_index_file
        RuntimeAttr? runtime_attr_override
    }
        
    Int num_cpu = if defined(runtime_attr_override) then select_first([select_first([runtime_attr_override]).cpu_cores, 4]) else 4
    Float disk_overhead = 10.0
    Float bam_size = size(bam_file, "GiB")
    Float ref_size = size(reference_fasta, "GiB")
    Float ref_index_size = size(reference_index_file, "GiB")
    Int vm_disk_size = ceil(bam_size + ref_size + ref_index_size + disk_overhead)
    String bam_file_name = basename(bam_file, ".bam")

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
  
        # only keep reads of insert sizes between 200 and 500 from a BAM file and write the reads that fulfil the condition to another file
        samtools view -h ~{bam_file} | \
        awk -v lower_bound=~{lower_bound_length} -v upper_bound=~{upper_bound_length}'substr($0,1,1)=="@" || ($9>= lower_bound && $9<=upper_bound) || ($9<=-lower_bound && $9>=-upper_bound)' | \
        samtools view -b > "~{bam_file_name}.~{subset_output_name}.bam" 
        
        # index bam file
        samtools index -@ ~{num_cpu} "~{bam_file_name}.~{subset_output_name}.bam"    
    >>>

    output {
        File output_bam_file = "~{bam_file_name}.~{subset_output_name}.bam"
        File output_bam_index = "~{bam_file_name}.~{subset_output_name}.bam.bai" 
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
