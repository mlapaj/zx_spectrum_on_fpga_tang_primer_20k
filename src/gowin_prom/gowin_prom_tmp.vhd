--Copyright (C)2014-2023 Gowin Semiconductor Corporation.
--All rights reserved.
--File Title: Template file for instantiation
--GOWIN Version: V1.9.9 Beta-4 Education
--Part Number: GW2A-LV18PG256C8/I7
--Device: GW2A-18
--Device Version: C
--Created Time: Fri Dec 29 22:53:35 2023

--Change the instance name and port connections to the signal names
----------Copy here to design--------

component Gowin_pROM
    port (
        dout: out std_logic_vector(7 downto 0);
        clk: in std_logic;
        oce: in std_logic;
        ce: in std_logic;
        reset: in std_logic;
        ad: in std_logic_vector(13 downto 0)
    );
end component;

your_instance_name: Gowin_pROM
    port map (
        dout => dout_o,
        clk => clk_i,
        oce => oce_i,
        ce => ce_i,
        reset => reset_i,
        ad => ad_i
    );

----------Copy end-------------------
