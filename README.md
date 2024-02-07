# imx-boot-image-builder : imx-bib.sh
Script to build i.MX Application Processor bootloader.  Similar to what is provided in Yocto Project, but using a simple bash script.

Supported i.MX targets: 
- 8mmini [8MMINILPD4-EVK](https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/evaluation-kit-for-the-i-mx-8m-mini-applications-processor:8MMINILPD4-EVK)
- 8mplus [8MPLUSLPD4-EVK](https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/evaluation-kit-for-the-i-mx-8m-plus-applications-processor:8MPLUSLPD4-EVK)
- 8mnano [8MNANOD4-EVK](https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/evaluation-kit-for-the-i-mx-8m-nano-applications-processor:8MNANOD4-EVK)
- 8mquad [MCIMX8M-EVK](https://www.nxp.com/design/development-boards/i-mx-evaluation-and-development-boards/evaluation-kit-for-the-i-mx-8m-applications-processor:MCIMX8M-EVK) 
- 8ulp [8ULPLPD4-EVK]
- mx93

## Example
To create the boot loader for 8ULPLPD4-EVK:
  `./imx-bib.sh -p 8ulp -b mickledore-6.1.55-2.2.0`
i.MX 93 A0 EVK (note 6.1.36-2.1.0 and later support A1 only)
  `./imx-bib.sh -p 93 -b mickledore-6.1.22-2.0.0`
  

# Usage
```
Usage: imx-bib.sh [-h] -p <soc> [-b] [-w <A0|A1>] [-c]
Create bootimage. Version  3.0
   -p soc       mandatory: options: 8ulp 8mm 8mn 8mp 8mq 93
   -b           optional: latest if not specified
                      BSP Release in the form yocto_release-nxp_version
		      example: -b hardknott-5.10.72-2.2.0
   -w A0|A1|A2  which 8ULP version, default A1. Note: A2 uses A1.bin
   -m           EVK with ddr4 memory. Supported: 8mn, 8mm, 8mp. If no -m, EVK with LPDDR4
   -c           make clean then make
   -r           remove all
   -d           enable script debug 
   -h           Help message

 Example 8ulp A1:    ./imx-bib.sh -p 8ulp 
 Example 8mn LPDDR4: ./imx-bib.sh -p 8mn 
 Example 8mn DDR4:   ./imx-bib.sh -p 8mn -m 

 ```
