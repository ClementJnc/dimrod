import dimrod

const 
    config_unit : TBasicUnitsConf = @[("m", (-1,2)), ("kg",(-1,1)), ("s", (-2,2))]
    uname_config = ("T", "v", "nodim")
    alias_config : TAliasConf= @[("N",@[1,1,-2]), ("Pa",@[-1,1,-2]), ("J",@[2,1,-2])]

init_unit(config_unit, uname_config, alias_config)
